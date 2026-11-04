"""Regression checks for the shared editor Biome configuration."""
from pathlib import Path
import re
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
NVIM = ROOT / "configs/nvim/lua/pedro/plugins"


class BiomeConfigTest(unittest.TestCase):
    def test_no_legacy_editor_integrations(self):
        for path in (NVIM / "autoformat.lua", NVIM / "lsp/mason.lua",
                     ROOT / "configs/vscodium/settings.json",
                     ROOT / "configs/vscodium/extensions.txt"):
            with self.subTest(path=path):
                self.assertNotRegex(path.read_text(), r"(?i)eslint|prettier")

    def test_neovim_formats_supported_languages(self):
        text = (NVIM / "autoformat.lua").read_text()
        for language in ("javascript", "javascriptreact", "typescript",
                         "typescriptreact", "json", "jsonc", "css", "graphql"):
            self.assertIn(f'{language} = {{ "biome-check" }}', text)
        self.assertIn('lua = { "stylua" }', text)
        self.assertIn('"biome"', (NVIM / "lsp/mason.lua").read_text())
        servers = (NVIM / "lsp/lsp.lua").read_text()
        self.assertIn("biome = {}", servers)
        self.assertIn("ts_ls = {}", servers)

    def test_vscodium_scopes_biome_and_requires_project_config(self):
        extensions = (ROOT / "configs/vscodium/extensions.txt").read_text().splitlines()
        self.assertIn("biomejs.biome", extensions)
        settings = (ROOT / "configs/vscodium/settings.json").read_text()
        self.assertEqual(settings.count('"editor.defaultFormatter": "biomejs.biome"'), 1)
        self.assertIn('"biome.requireConfiguration": true', settings)
        self.assertIn('"source.fixAll.biome": "explicit"', settings)
        self.assertIn('"source.organizeImports.biome": "explicit"', settings)
        match = re.search(r'"(\[javascript\].*?)": \{(.*?)\n  \}', settings, re.S)
        self.assertIsNotNone(match)
        self.assertIn("[typescriptreact]", match[1])
        self.assertIn("[jsonc]", match[1])
        self.assertIn('"editor.formatOnSave": true', match[2])

    @unittest.skipUnless(shutil.which("nvim"), "Neovim is not installed")
    def test_lua_configs_parse(self):
        for path in (NVIM / "autoformat.lua", NVIM / "lsp/mason.lua", NVIM / "lsp/lsp.lua"):
            result = subprocess.run(
                ["nvim", "--headless", "-u", "NONE", "-i", "NONE",
                 "+lua assert(loadfile(" + repr(str(path)) + "))", "+qa"],
                capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("Error", result.stderr)


if __name__ == "__main__":
    unittest.main()
