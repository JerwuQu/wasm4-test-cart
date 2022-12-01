# wasm4-test-cart

A [WASM-4](https://wasm4.org) runtime implementation checker.

## Building

Build the test cart by running:

```shell
zig build
```

Then run it with:

```shell
w4 run zig-out/cart.opt.wasm
# or
w4 run-native zig-out/cart.opt.wasm
# or
your-runtime zig-out/cart.opt.wasm
```

## Links

- [WASM-4 Documentation](https://wasm4.org/docs)
