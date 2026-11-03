"""Static cache contract check; Godot runtime test verifies real identities."""

from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]


class CacheSourceContract(unittest.TestCase):
    def test_source_guards_revisions(self):
        contour=(ROOT/'scripts/coast_contour.gd').read_text()
        builder=(ROOT/'scripts/coast_builder.gd').read_text()
        definition=(ROOT/'scripts/island_definition.gd').read_text()
        self.assertIn('if _shore_cache_instance == island.get_instance_id() and _shore_cache_revision == island.coastline_revision:',contour)
        self.assertIn('if _sdf_cache != null and _sdf_cache_instance == island.get_instance_id()',builder)
        self.assertIn('if _profile_cache != null and _profile_cache_instance == island.get_instance_id()',builder)
        self.assertIn('if levels[index] == height_level:',definition)
        self.assertIn('if (water[index] != 0) == enabled:',definition)
        self.assertIn('if (land_mask[index] != 0) == enabled:',definition)


if __name__=='__main__':
    unittest.main()
