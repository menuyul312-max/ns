class_name IslandWaterValidator
extends RefCounted
## Advisory rules for our original editor; not assertions about ACNH restrictions.


static func audit(island: IslandDefinition) -> Dictionary:
	var count: int = island.width * island.depth
	var visited := PackedByteArray()
	visited.resize(count)
	visited.fill(0)
	var component_sizes: Array[int] = []
	var water_count: int = 0
	var border_count: int = 0
	var steep_edges: int = 0
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_water(x, z):
				continue
			water_count += 1
			if x == 0 or z == 0 or x == island.width - 1 or z == island.depth - 1:
				border_count += 1
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var adjacent: Vector2i = Vector2i(x, z) + direction
				if island.is_water(adjacent.x, adjacent.y) and absi(island.height_at(x, z) - island.height_at(adjacent.x, adjacent.y)) > 1:
					steep_edges += 1
			var initial_index: int = z * island.width + x
			if visited[initial_index] != 0:
				continue
			var queue: Array[Vector2i] = [Vector2i(x, z)]
			visited[initial_index] = 1
			var head: int = 0
			while head < queue.size():
				var current: Vector2i = queue[head]
				head += 1
				for direction in directions:
					var next: Vector2i = current + direction
					if not island.is_water(next.x, next.y):
						continue
					var next_index: int = next.y * island.width + next.x
					if visited[next_index] != 0:
						continue
					visited[next_index] = 1
					queue.append(next)
			component_sizes.append(queue.size())
	var notices: Array[String] = []
	if water_count == 0:
		notices.append("Tidak ada air pada denah")
	if component_sizes.size() > 1:
		notices.append("%s jaringan air terpisah (boleh untuk kolam)" % component_sizes.size())
	if steep_edges > 0:
		notices.append("%s perubahan elevasi air lebih dari 1 tingkat" % steep_edges)
	return {
		"water_tiles": water_count,
		"components": component_sizes.size(),
		"component_sizes": component_sizes,
		"border_water_tiles": border_count,
		"waterfalls": island.waterfall_edge_count(),
		"steep_edges": steep_edges,
		"notices": notices
	}
