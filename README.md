# gfx-test-cart

A [WASM-4](https://wasm4.org) runtime implementation checker.

## Building

Build the test cart by running:

```shell
zig build
```

Then run it with:

```shell
w4 run zig-out/lib/cart.wasm
# or
w4 run-native zig-out/lib/cart.wasm
# or
your-runtime zig-out/lib/cart.wasm
```

## Links

- [WASM-4 Documentation](https://wasm4.org/docs)
