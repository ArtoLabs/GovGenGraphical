"""Bodies on the map: people walk to where things are done, and the walk is what the action takes
(core/movement.py, data/rules/map.json 'camp', 'travel', 'places')."""
import json
import unittest

from core.actions import Action
from core.engine import GameEngine
from tests.helpers import become_actor, do, find, give_work, new_engine
from world.map import BY_CODE, TERRAIN, WorldMap, position_at


def strip(rows):
    return WorldMap(len(rows[0]), len(rows), [list(r) for r in rows])


class PathTest(unittest.TestCase):
    def test_walks_round_what_cannot_be_crossed(self):
        p, w = TERRAIN["plains"].code, TERRAIN["deep_water"].code
        m = strip([p * 5, p + w * 3 + p, p + w * 3 + p, p * 5])
        path = m.find_path((0, 1), (4, 2))
        self.assertEqual((path[0], path[-1]), ((0, 1), (4, 2)))
        self.assertTrue(all(BY_CODE[m.tiles[y][x]].walkable for x, y in path))
        self.assertTrue(all(max(abs(a[0] - b[0]), abs(a[1] - b[1])) == 1 for a, b in zip(path, path[1:])))

    def test_takes_the_easy_ground(self):
        p, f = TERRAIN["plains"].code, TERRAIN["deep_forest"].code
        m = strip([p * 7, p + f * 5 + p, p * 7])
        direct = [(x, 1) for x in range(7)]
        self.assertLess(m.path_cost(m.find_path((0, 1), (6, 1))), m.path_cost(direct))

    def test_somewhere_out_of_reach_gets_as_near_as_can_be(self):
        p, w = TERRAIN["plains"].code, TERRAIN["deep_water"].code
        m = strip([p * 2 + w + p * 2])
        self.assertEqual(m.find_path((0, 0), (4, 0)), [(0, 0), (1, 0)])

    def test_position_part_way_along_a_walk(self):
        leg = {"t0": 100, "t1": 200, "path": [[0, 0], [1, 0], [2, 0]], "at": [0, 0.5, 1]}
        self.assertEqual(position_at([2, 0], [leg], 50), (0, 0))
        self.assertEqual(position_at([2, 0], [leg], 125), (0.5, 0))
        self.assertEqual(position_at([2, 0], [leg], 175), (1.5, 0))
        self.assertEqual(position_at([2, 0], [leg], 300), (2, 0))


class BodiesTest(unittest.TestCase):
    def setUp(self):
        self.e = new_engine(0)
        self.m = self.e.movement
        self.world = self.m.world

    def test_everyone_starts_in_camp_at_a_sleeping_place_of_their_own(self):
        beds = [tuple(b["bed"]) for b in self.m.people.values()]
        self.assertEqual(len(beds), len(self.e.players))
        self.assertEqual(len(set(beds)), len(beds))
        self.assertTrue(all(self.m.in_camp(p.name) for p in self.e.players))

    def test_a_trip_takes_the_walk_out_the_work_and_the_walk_back(self):
        give_work(self.e, "Alice")
        alice = become_actor(self.e, "Alice")
        start = self.e.clock
        action = find(self.e, alice, "work", task="fetch_water")
        self.assertTrue(self.e.apply(alice, action))
        b = self.m.people["Alice"]
        out, back = b["legs"][0], b["legs"][-1]
        river = tuple(out["path"][-1])
        self.assertTrue(self.world.terrain_at(*river).fresh_water)
        self.assertEqual(tuple(back["path"][-1]), self.world.spots["store"])   # home again with the water
        walked = sum(leg["t1"] - leg["t0"] for leg in b["legs"])
        on_the_spot = self.e.base_duration(action, alice) * 0.5
        self.assertAlmostEqual(self.e.free_at["Alice"] - start, walked + on_the_spot, delta=1)
        self.assertGreater(walked, 0)
        # Half way through the work she is at the river, and the store is out of reach.
        self.e.game_state.clock = (out["t1"] + back["t0"]) // 2
        self.assertEqual(self.m.tile("Alice"), river)
        self.assertFalse(self.m.in_camp("Alice"))
        self.assertFalse(self.e.possessions.restock(alice))

    def test_a_place_further_off_takes_longer(self):
        give_work(self.e, "Alice")
        alice = become_actor(self.e, "Alice")
        action = Action("work", {"task": "gather_wood"})
        near = self.e.duration(action, alice)
        far_tile = self.world.pick("scouting", self.m.rng, 30, 40)
        self.e.production.sites.append({"id": 99, "kind": "wood", "by": "Bob", "loads": 3, "total": 3,
                                        "found": self.e.clock, "until": self.e.clock + 10 ** 6, "at": list(far_tile)})
        self.m._planned.clear()
        self.assertGreater(self.e.duration(action, alice), near)

    def test_sleep_is_in_ones_own_bed_and_warming_up_is_beside_the_fire(self):
        do(self.e, "Alice", "care", kind="warm_up")
        fire = self.world.spots["fire"]
        end = self.m.people["Alice"]["pos"]
        self.assertEqual(max(abs(end[0] - fire[0]), abs(end[1] - fire[1])), 1)
        do(self.e, "Bob", "care", kind="sleep")
        self.assertEqual(self.m.people["Bob"]["pos"], self.m.people["Bob"]["bed"])

    def test_waking_someone_stops_them_where_they_are(self):
        do(self.e, "Bob", "care", kind="sleep")
        bob = self.e.player("Bob")
        self.e.game_state.clock += 1
        self.assertTrue(self.e.interrupt(bob))
        self.assertEqual(self.m.people["Bob"]["legs"], [])
        self.assertEqual(self.m.people["Bob"]["pos"], list(self.m.tile("Bob")))

    def test_votes_take_no_walking(self):
        alice = become_actor(self.e, "Alice")
        vote = next(a for a in self.e.legal_actions(alice) if a.type in ("vote", "nominate"))
        self.assertIsNone(self.m.plan(alice, vote))
        self.assertEqual(self.e.duration(vote, alice), self.e.base_duration(vote, alice))

    def test_bodies_are_saved_and_loaded(self):
        give_work(self.e, "Alice")
        do(self.e, "Alice", "work", task="fetch_water")
        again = GameEngine.from_dict(json.loads(json.dumps(self.e.to_dict())))
        self.assertEqual(again.movement.people["Alice"], self.m.people["Alice"])
        self.assertEqual(again.movement.position("Alice"), self.m.position("Alice"))

    def test_the_view_says_where_everyone_is(self):
        view = self.e.observe(self.e.players[0])["map"]
        self.assertEqual({p["name"] for p in view["people"]}, {p.name for p in self.e.players})
        self.assertEqual(tuple(view["spots"]["fire"]), self.world.spots["fire"])
        json.dumps(view)  # plain data


if __name__ == "__main__":
    unittest.main()
