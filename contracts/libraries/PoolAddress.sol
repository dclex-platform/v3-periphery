// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    // POOL_INIT_CODE_HASH must equal keccak256(type(UniswapV3Pool).creationCode)
    // for the v3-core / solc / optimizer combination currently compiled, or every
    // address this library derives (used by NonfungiblePositionManager, SwapRouter,
    // Quoter) will be wrong — the target pool has no code, `slot0()` reverts with
    // empty data, and mint/swap/quote calls silently fail.
    //
    // Critically, the hash differs by compiler pipeline: standalone (no --via-ir)
    // vs IR-based (--via-ir) compiles of UniswapV3Pool produce different bytecode
    // and therefore different hashes. The value below is the --via-ir hash, which
    // is what this repo ships (foundry.toml default + script invocations pass
    // --via-ir). Do NOT read the hash from out/UniswapV3Pool.sol/*.json unless
    // that artifact itself was built with --via-ir — the JSON can be stale from
    // a prior non-IR build and silently disagree with what the factory actually
    // deploys. Authoritative source: `forge test test/PoolInitCodeHash.t.sol
    // --via-ir` — it reads `type(UniswapV3Pool).creationCode` from the live
    // compile context.
    //
    // Solidity constants are literals, so bumping v3-core or changing
    // solc/optimizer/pipeline settings requires updating this value by hand.
    // `test/PoolInitCodeHash.t.sol` guards it so CI fails loudly the next time
    // the two drift apart.
    bytes32 internal constant POOL_INIT_CODE_HASH = 0x54488334146a9568201119ab62bd8fcc957d3c9a15289c14f66505c87d5e6b89;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            factory,
                            keccak256(abi.encode(key.token0, key.token1, key.fee)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
