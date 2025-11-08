#include "game.h"
#include <stdio.h>
#include <stdlib.h>
#define STB_DS_IMPLEMENTATION
#include "stb_ds.h"

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

typedef struct {
  int cost;
  Hex hex;
} Element;

typedef struct {
  Element *data;
  int size;
  int capacity;
} BinaryHeap;

BinaryHeap *init(int capacity) {
  BinaryHeap *heap = malloc(sizeof(BinaryHeap));
  heap->data = malloc(sizeof(Element) * capacity);
  heap->size = 0;
  heap->capacity = capacity;
  return heap;
}

void resize(BinaryHeap *heap) {
  heap->capacity *= 2;
  heap->data = realloc(heap->data, sizeof(Element) * heap->capacity);
}

int parent(int i) { return (i - 1) / 2; }
int left(int i) { return (2 * i) + 1; }
int right(int i) { return (2 * i) + 2; }

bool is_empty(BinaryHeap *heap) { return heap->size == 0; }

int cost(BinaryHeap *heap, int idx) { return heap->data[idx].cost; }

static void swap(Element *a, Element *b) {
  Element temp = *a;
  *a = *b;
  *b = temp;
}

static void heapify_up(BinaryHeap *heap, int idx) {
  int p = parent(idx);
  if (idx && cost(heap, p) > cost(heap, idx)) {
    swap(&heap->data[idx], &heap->data[p]);
    heapify_up(heap, p);
  }
}

static void heapify_down(BinaryHeap *heap, int idx) {
  int smallest = idx;
  int l = left(idx);
  int r = right(idx);
  if (l < heap->size && cost(heap, l) < cost(heap, smallest))
    smallest = l;
  if (r < heap->size && cost(heap, r) < cost(heap, smallest))
    smallest = r;

  if (smallest != idx) {
    swap(&heap->data[idx], &heap->data[smallest]);
    heapify_down(heap, smallest);
  }
}

static void insert(BinaryHeap *heap, Element el) {
  if (heap->size == heap->capacity) {
    resize(heap);
  }
  heap->data[heap->size++] = el;
  heapify_up(heap, heap->size - 1);
}

static Element peek(BinaryHeap *heap) { return heap->data[0]; }

static Element pop(BinaryHeap *heap) {
  if (heap->size == 0)
    return (Element){-1, NULL_HEX};
  Element head = peek(heap);
  swap(&heap->data[0], &heap->data[--heap->size]);
  heapify_down(heap, 0);
  return head;
}

Hex *find_path(Unit *u, Hex start, Hex end) {
  bool found = false;
  BinaryHeap *frontier = init(50);
  insert(frontier, (Element){0, start});

  struct {
    Hex key;
    Hex value;
  } *came_from = NULL;

  struct {
    Hex key;
    int value;
  } *cost_so_far = NULL;

  while (!found && !is_empty(frontier)) {
    Element current = pop(frontier);

    Hex *next = get_neighbours(current.hex);

    for (int i = 0; i < 6; i++) {
      if (hex_inbounds(next[i])) {
        MapPosition *mp = get_map_position_from_hex(next[i]);

        int speed = unit_speed(u, mp);
        int cost = 360/speed;
        if (speed == 0) {
          cost = 1000;
        }
        int new_cost = hmget(cost_so_far, current.hex) + cost;
        if (hmgeti(cost_so_far, next[i]) == -1 ||
            new_cost < hmget(cost_so_far, next[i])) {
          hmput(cost_so_far, next[i], new_cost);
          int priority = new_cost + hex_distance(next[i], end);
          insert(frontier, (Element){priority, next[i]});
          hmput(came_from, next[i], current.hex);
        }
        if (same_hex(next[i], end)) {
          found = true;
          break;
        }
      }
    }
  }

  if (!found) {
    return NULL;
  }

  Hex *path = NULL;
  Hex curr = end;
  arrput(path, curr);
  while (!same_hex(curr, start)) {
    curr = hmget(came_from, curr);
    arrput(path, curr);
  }

  hmfree(came_from);
  hmfree(cost_so_far);
  free(frontier->data);
  free(frontier);

  return path;
}
