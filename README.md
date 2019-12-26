# zig-utilities

## Parts

- `GrowableArray` (`growable_array.zig`); just a dynamic array, you should
  probably use `std.array_list.ArrayList` instead, but this one has a few
  characteristics I wanted (like initial capacity specification on `init` as
  well as sliced additions, not just single `append`s, etc.)

- `zip.zig`; meant for interleaving/deinterleaving memory, probably a bad name
  choice.