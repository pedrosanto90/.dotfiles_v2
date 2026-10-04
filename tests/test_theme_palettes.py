"""Validate the desktop-neutral palettes against their Waybar counterparts."""
import json
import re
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
PALETTES = ROOT / "configs/debian-sway-dev/theme/palettes"
WAYBAR = ROOT / "configs/waybar"
MAPPING = {
    "tokyonight-dark": "colors-dark.css",
    "tokyonight-light": "colors-light.css",
    "kanagawa-dark": "colors-kanagawa-dark.css",
    "kanagawa-light": "colors-kanagawa-light.css",
    "rose-pine-dark": "colors-rose-pine-dark.css",
    "everforest-dark": "colors-everforest-dark.css",
    "everforest-light": "colors-everforest-light.css",
    "catppuccin-dark": "colors-catppuccin-mocha.css",
    "catppuccin-light": "colors-catppuccin-latte.css",
    "gruvbox-dark": "colors-gruvbox-dark.css",
    "gruvbox-light": "colors-gruvbox-light.css",
    "nightfox-dark": "colors-nightfox-dark.css",
}
COLOR_KEYS = {
    "background": "tooltip_background",
    "foreground": "foreground",
    "secondary": "secondary_foreground",
    "selected": "selected_foreground",
    "muted": "muted",
    "border": "border",
    "accent": "blue",
    "success": "green",
    "warning": "yellow",
    "orange": "orange",
    "danger": "red",
    "purple": "purple",
}


def read_waybar_palette(path):
    values = {}
    for name, value in re.findall(r"@define-color\s+(\w+)\s+([^;]+);", path.read_text()):
        values[name] = value
    return values


class ThemePaletteTest(unittest.TestCase):
    def test_palette_set_is_complete(self):
        self.assertEqual({path.stem for path in PALETTES.glob("*.json")}, set(MAPPING))

    def test_palettes_are_valid_and_match_waybar(self):
        for theme, css_name in MAPPING.items():
            with self.subTest(theme=theme):
                palette = json.loads((PALETTES / f"{theme}.json").read_text())
                waybar = read_waybar_palette(WAYBAR / css_name)
                self.assertEqual(palette["id"], theme)
                self.assertIn(palette["mode"], {"light", "dark"})
                self.assertTrue(palette["label"])
                for json_key, css_key in COLOR_KEYS.items():
                    self.assertEqual(palette[json_key].lower(), waybar[css_key].lower())

                match = re.fullmatch(
                    r"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([01](?:\.\d+)?)\)",
                    waybar["bar_background"],
                )
                self.assertIsNotNone(match)
                red, green, blue = (int(value) for value in match.groups()[:3])
                alpha = round(float(match.group(4)) * 255)
                expected = f"#{alpha:02x}{red:02x}{green:02x}{blue:02x}"
                self.assertEqual(palette["barBackground"].lower(), expected)
                self.assertEqual(palette["surface"].lower(), f"#{red:02x}{green:02x}{blue:02x}")


if __name__ == "__main__":
    unittest.main()
