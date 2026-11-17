"""The world map: a grid of terrain tiles grown from a seed (world/map.py, data/rules/map.json)."""
import random
import unittest

from ui.model import skill_average
from world.map import BY_CODE, TERRAIN, Structure, WorldMap, generate


class WorldMapTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = generate(3, 80, 50)

    def test_same_seed_same_world(self):
        again = generate(3, 80, 50)
        self.assertEqual(self.m.tiles, again.tiles)
        self.assertEqual(self.m.home, again.home)
        self.assertNotEqual(self.m.tiles, generate(4, 80, 50).tiles)

    def test_making_a_map_leaves_the_games_dice_alone(self):
        random.seed(11)
        expected = random.random()
        random.seed(11)
        generate(5, 40, 30)
        self.assertEqual(random.random(), expected)

    def test_every_tile_is_a_known_terrain(self):
        self.assertEqual((len(self.m.tiles), len(self.m.tiles[0])), (50, 80))
        self.assertTrue(all(code in BY_CODE for row in self.m.tiles for code in row))
        kinds = {BY_CODE[code].key for row in self.m.tiles for code in row}
        self.assertTrue({"plains", "forest", "deep_water"} <= kinds, kinds)

    def test_home_is_on_open_ground(self):
        x, y = self.m.home
        self.assertTrue(all(self.m.terrain_at(tx, ty).buildable for tx, ty in self.m.near(x, y, 1)))

    def test_structures_cover_whole_tiles_and_cannot_overlap(self):
        m = WorldMap.from_dict(self.m.to_dict())
        x, y = m.home
        hut = Structure("hut", "Hut", x, y, 2, 2)
        self.assertTrue(m.build(hut))
        self.assertIs(m.structure_at(x + 1, y + 1), hut)
        self.assertFalse(m.can_build(x + 1, y + 1))            # taken
        self.assertFalse(m.build(Structure("hut", "Hut", x - 1, y - 1, 2, 2)))  # would overlap
        self.assertFalse(m.can_build(-1, 0))                   # off the map
        m.remove(hut)
        self.assertTrue(m.can_build(x, y, 2, 2))

    def test_nothing_stands_on_water(self):
        m = WorldMap(2, 1, [[TERRAIN["deep_water"].code, TERRAIN["plains"].code]])
        self.assertFalse(m.can_build(0, 0))
        self.assertTrue(m.can_build(1, 0))
        self.assertFalse(m.can_build(0, 0, 2, 1))

    def test_saves_and_loads(self):
        m = WorldMap.from_dict(self.m.to_dict())
        m.build(Structure("hut", "Hut", *m.home))
        again = WorldMap.from_dict(m.to_dict())
        self.assertEqual(again.tiles, m.tiles)
        self.assertEqual(again.home, m.home)
        self.assertEqual(again.structure_at(*m.home).name, "Hut")


class SkillAverageTest(unittest.TestCase):
    def test_average_counts_unpractised_skills(self):
        self.assertEqual(skill_average({"a": 2.0, "b": 0.0, "c": 1.0}), 1.0)
        self.assertEqual(skill_average({}), 0.0)


if __name__ == "__main__":
    unittest.main()
