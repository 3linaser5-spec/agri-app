import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from parsing import (  # noqa: E402
    SCHEMA,
    build_messages,
    extract_json,
    normalize,
)


class ExtractJsonTests(unittest.TestCase):
    def test_plain(self):
        self.assertEqual(extract_json('{"a": 1}'), {"a": 1})

    def test_fenced(self):
        self.assertEqual(extract_json('x\n```json\n{"a": 2}\n```\ny'), {"a": 2})

    def test_surrounded_by_prose(self):
        self.assertEqual(extract_json('هذا الناتج: {"a": 3} شكرا'), {"a": 3})

    def test_rejects_garbage(self):
        for bad in ("", "no json", "[1, 2]", "{broken"):
            with self.assertRaises(ValueError):
                extract_json(bad)


class NormalizeTests(unittest.TestCase):
    def good(self, **over):
        raw = {
            "is_plant": True,
            "plant_name_ar": "طماطم",
            "health_status": "diseased",
            "diagnosis_ar": "اللفحة المبكرة",
            "confidence": 0.9,
            "symptoms": ["بقع بنية"],
            "treatment_organic": ["إزالة الأوراق المصابة"],
            "treatment_chemical": ["مبيد فطري نحاسي"],
            "prevention": ["تجنب الري بالرش"],
            "needs_expert": False,
        }
        raw.update(over)
        return raw

    def test_valid_passes_through(self):
        r = normalize(self.good())
        self.assertTrue(r["is_plant"])
        self.assertEqual(r["plant_name_ar"], "طماطم")
        self.assertEqual(r["confidence"], 0.9)
        self.assertFalse(r["needs_expert"])
        self.assertIn("disclaimer", r)

    def test_percentage_confidence_is_scaled(self):
        self.assertAlmostEqual(normalize(self.good(confidence=85))["confidence"], 0.85)

    def test_confidence_is_clamped_and_bool_rejected(self):
        self.assertEqual(normalize(self.good(confidence=500))["confidence"], 1.0)
        self.assertEqual(normalize(self.good(confidence=-3))["confidence"], 0.0)
        self.assertEqual(normalize(self.good(confidence=True))["confidence"], 0.0)

    def test_low_confidence_forces_expert(self):
        self.assertTrue(normalize(self.good(confidence=0.3))["needs_expert"])

    def test_unclear_forces_expert(self):
        self.assertTrue(normalize(self.good(health_status="unclear"))["needs_expert"])

    def test_unknown_enums_fall_back(self):
        r = normalize(self.good(health_status="weird", severity="extreme"))
        self.assertEqual(r["health_status"], "unclear")
        self.assertIsNone(r["severity"])

    def test_not_a_plant(self):
        r = normalize({"is_plant": False, "diagnosis_ar": "x", "confidence": 1})
        self.assertFalse(r["is_plant"])
        self.assertEqual(r["confidence"], 0.0)
        self.assertEqual(r["symptoms"], [])

    def test_missing_is_plant_means_not_a_plant(self):
        self.assertFalse(normalize({"plant_name_ar": "x"})["is_plant"])

    def test_lists_are_cleaned_and_capped(self):
        r = normalize(self.good(symptoms=["a", 5, "", " b "] + ["c"] * 20))
        self.assertEqual(r["symptoms"][:2], ["a", "b"])
        self.assertLessEqual(len(r["symptoms"]), 8)
        self.assertEqual(normalize(self.good(symptoms="oops"))["symptoms"], [])


class PromptTests(unittest.TestCase):
    def test_messages_carry_the_image_and_crop(self):
        msgs = build_messages("QUJD", "قمح")
        self.assertEqual(msgs[0]["role"], "system")
        self.assertEqual(msgs[1]["images"], ["QUJD"])
        self.assertIn("قمح", msgs[1]["content"])

    def test_schema_requires_core_fields(self):
        for key in ("is_plant", "health_status", "confidence", "treatment_chemical"):
            self.assertIn(key, SCHEMA["required"])


if __name__ == "__main__":
    unittest.main()
