#include <stdbool.h>

typedef struct Hex {
  // A doubled height implementation
  int x; // col
  int y; // row
} Hex;

static const Hex NULL_HEX = {-1, -1};

int hex_distance(Hex a, Hex b);
int hex_line(Hex a, Hex b, Hex* out, int size);
Hex *get_neighbours(Hex a);
int get_hexes_in_range(Hex a, int range, Hex *out);
Hex nearest_hex(float x, float y);
bool same_hex(Hex a, Hex b);
