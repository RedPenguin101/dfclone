#+private file
package game

/* A binary heap is a binary tree which satisfies the 'heap property':
   Any given node is greater than it's child node (a max-heap) or
   smaller than its child nodes (a min-heap).

   The key operations on a heap are:
   - To heapify: 'sorting' the binary tree - see the function for details.
   - Insert: insert a new node at the end, then heapify
   - Delete: find the element to delete, swap it with the last element
     then heapify
   - Peek: return the maximum element from the max-heap, or minimum from
     the min heap. In both cases, it's just the root of the tree.
   - Pop: return the top of the heap, delete it, and heapify.

   Peek is O(1), Insert and delete are both O(log n) (which is
   basically the cost of heapification)

   The Binary Tree is stored in an array. The relationships between the
   nodes are as follows:
   - parent(i) = (i-1)/2
   - left(i) = (2*i) + 1
   - right(i) = (2*i) + 2
*/

Element :: struct {
	cost:int,
	v:V3i,
}

BinaryHeap :: [dynamic]Element

parent :: proc(i:int) -> int {return (i-1)/2}
left :: proc(i:int) -> int {return (2*i)+1}
right :: proc(i:int) -> int {return (2*i)+2}

is_empty :: proc(heap:BinaryHeap) -> bool {return len(heap) == 0}
cost :: proc(heap:BinaryHeap, idx:int) -> int {return heap[idx].cost}

heap_peek :: proc(heap:BinaryHeap) -> Element {return heap[0]}
heap_pop :: proc(heap:^BinaryHeap) -> Element {
	if len(heap) == 0 do return {-1,{}}

	head := heap_peek(heap^)
	unordered_remove(heap, 0)
	heapify_down(heap, 0)
	return head
}

swap :: proc(a,b:^Element) {
	temp := a^
	a^ = b^
	b^ = temp
}

heapify_up :: proc(heap:^BinaryHeap, idx:int) {
	p := parent(idx)
	if idx != 0 && cost(heap^, p) > cost(heap^, idx) {
		swap(&heap[idx], &heap[p])
		heapify_up(heap, p)
	}
}

heapify_down :: proc(heap:^BinaryHeap, idx:int) {
	smallest := idx
	l := left(idx)
	r := right(idx)
	if l < len(heap) && cost(heap^, l) < cost(heap^, smallest) {
		smallest = l
	}
	if r < len(heap) && cost(heap^, r) < cost(heap^, smallest) {
		smallest = r
	}

	if smallest != idx {
		swap(&heap[idx], &heap[smallest])
		heapify_down(heap, smallest)
	}
}

insert :: proc(heap:^BinaryHeap, el:Element) {
	append(heap, el)
	heapify_up(heap, len(heap)-1)
}

@(private="package")
find_path :: proc(mp:^Map, start, end: V3i, path:^[dynamic]V3i) -> bool {
	clear(path)
	MAX_ITERATIONS :: 1000

	frontier := make(BinaryHeap)
	came_from := make(map[V3i]V3i)
	cost_so_far := make(map[V3i]int)
	defer {
		delete(frontier)
		delete(came_from)
		delete(cost_so_far)
	}

	found := false
	its := 0
	insert(&frontier, {0, start})

	for !found && !is_empty(frontier) && its < MAX_ITERATIONS {
		its += 1
		current := heap_pop(&frontier)
		next := get_neighbours(current.v)

		for n in next {
			tile := get_map_tile(mp, n)
			if n == end
			{
				came_from[n] = current.v
				found = true
				break
			}
			else if tile != nil && tile.content.shape != .Solid
			{
				mhd := mh_distance(n, current.v)
				assert(mhd == 1 || mhd == 2)
				cost := mhd
				csf, exists := cost_so_far[current.v]
				new_cost := cost_so_far[current.v] + cost if exists else cost
				csf, exists = cost_so_far[n]
				if !exists || new_cost < csf {
					cost_so_far[n] = new_cost
					priority := new_cost + 1
					insert(&frontier, Element{priority, n})
					came_from[n] = current.v
				}
			}
		}
	}
	if !found {
		return found
	}

	curr := end
	append(path, end)
	for curr != start {
		curr = came_from[curr]
		append(path, curr)
	}

	return found
}
