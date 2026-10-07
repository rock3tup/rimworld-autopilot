"""Tests for macOS / MPS Apple Silicon device loading, fallback, and decision cycles."""

from unittest import TestCase, mock
import types
import warnings
import sys
from pathlib import Path

import torch
import rimworld_laya as bridge
from laya_decisions import ask_laya_choice


class MockFailingAgent:
    """Simulates a model that fails on MPS during predict."""

    def __init__(self, device: str = "mps"):
        self.device = torch.device(device)
        self.dtype = torch.float16
        self.amp_enabled = True
        self.model = mock.MagicMock()

    def predict(self, state, questions):
        if str(self.device) == "mps":
            raise RuntimeError("MPS backend error: out of memory or unsupported operation")
        return {
            "model": "mock-laya-cpu",
            "answers": {
                qid: {
                    "type": "choice",
                    "choice": next(iter(q.get("criteria", {"keep_current_plan": ""}))) if q.get("criteria") else "keep_current_plan",
                    "confidence": 0.95,
                    "probabilities": {opt: 1.0 / len(q["criteria"]) for opt in q.get("criteria", {})},
                }
                for qid, q in questions.items()
            },
            "usage": {"input_tokens": 50, "output_tokens": 0},
        }


class MacOSLayaDeviceTests(TestCase):

    def test_load_agent_mps_fallback_on_error(self):
        """If loading on MPS raises an exception, load_agent falls back to CPU."""
        call_count = 0

        def fake_laya_load(model_source, device=None):
            nonlocal call_count
            call_count += 1
            if device == "mps":
                raise RuntimeError("MPS device initialization failed")
            return types.SimpleNamespace(device=torch.device("cpu"), predict=lambda s, q: {})

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            with mock.patch("laya.load", side_effect=fake_laya_load):
                agent = bridge.load_agent(bridge.DEFAULT_MODEL, "mps")
                self.assertIsInstance(agent, bridge.SafeDecisionAgent)
                self.assertEqual(call_count, 2)  # First mps (failed), second cpu
                self.assertTrue(any("falling back to cpu" in str(item.message).lower() for item in w))

    def test_load_agent_cpu_and_auto(self):
        """load_agent works cleanly with cpu and auto devices."""
        fake_inner = types.SimpleNamespace(device=torch.device("cpu"))
        with mock.patch("laya.load", return_value=fake_inner):
            agent_cpu = bridge.load_agent(bridge.DEFAULT_MODEL, "cpu")
            self.assertIsInstance(agent_cpu, bridge.SafeDecisionAgent)

            agent_auto = bridge.load_agent(bridge.DEFAULT_MODEL, "auto")
            self.assertIsInstance(agent_auto, bridge.SafeDecisionAgent)

    def test_safe_decision_agent_mps_runtime_fallback(self):
        """SafeDecisionAgent.predict catches MPS runtime errors, falls back to CPU, and retries."""
        failing_inner = MockFailingAgent(device="mps")
        agent = bridge.SafeDecisionAgent(failing_inner)

        questions = {
            "colony_action": {
                "type": "choice",
                "instructions": "Select safe action",
                "criteria": {"keep_current_plan": "Keep", "prioritize_cooking": "Cook"},
            }
        }
        state = {"task": "Work"}

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            result = agent.predict(state, questions)

        self.assertEqual(str(failing_inner.device), "cpu")
        self.assertFalse(failing_inner.amp_enabled)
        self.assertEqual(result["answers"]["colony_action"]["choice"], "keep_current_plan")
        self.assertTrue(any("Falling back to CPU" in str(item.message) for item in w))

    def test_ask_laya_choice_with_mps_fallback_agent(self):
        """ask_laya_choice produces valid decision results when MPS fails and falls back."""
        failing_inner = MockFailingAgent(device="mps")
        agent = bridge.SafeDecisionAgent(failing_inner)

        options = {"keep_current_plan": "Keep", "prioritize_construction": "Build"}
        choice, raw = ask_laya_choice(agent, {"task": "Build"}, "test_q", "Instructions", options)

        self.assertIn(choice, options)
        self.assertEqual(str(failing_inner.device), "cpu")

    def test_decide_function_with_failing_mps_agent(self):
        """bridge.decide handles model prediction with graceful CPU fallback."""
        failing_inner = MockFailingAgent(device="mps")
        agent = bridge.SafeDecisionAgent(failing_inner)

        snapshot = {
            "map": {"enemies": 0},
            "combat": {"colonists": [], "hostiles": [], "available": True},
            "colonists": [{"id": 1, "name": "Worker", "health": 1.0, "hunger": 0.8, "work_priorities": {}}],
            "game": {"is_paused": False},
        }

        decision = bridge.decide(agent, snapshot, confidence_threshold=0.0)
        self.assertIn("choice", decision)
        self.assertEqual(str(failing_inner.device), "cpu")

    def test_macos_gui_and_director_defaults(self):
        """Default device on macOS evaluates to 'mps'."""
        import importlib
        from laya_gui import services

        with mock.patch("sys.platform", "darwin"):
            importlib.reload(services)
            self.assertEqual(services.DEFAULT_CONFIG["device"], "mps")
        importlib.reload(services)
