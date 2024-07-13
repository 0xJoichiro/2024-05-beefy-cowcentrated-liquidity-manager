// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {BeefyVaultConcLiq} from "contracts/vault/BeefyVaultConcLiq.sol";
import {BeefyVaultConcLiqFactory} from "contracts/vault/BeefyVaultConcLiqFactory.sol";
import {StrategyPassiveManagerVelodrome} from "contracts/strategies/velodrome/StrategyPassiveManagerVelodrome.sol";
import {StrategyFactory} from "contracts/strategies/StrategyFactory.sol";
import {BeefyRewardPoolFactory} from "contracts/rewardpool/BeefyRewardPoolFactory.sol";
import {BeefyRewardPool} from "contracts/rewardpool/BeefyRewardPool.sol";
import {StratFeeManagerInitializable} from "contracts/strategies/StratFeeManagerInitializable.sol";
import {IStrategyConcLiq} from "contracts/interfaces/beefy/IStrategyConcLiq.sol";
import {VeloSwapUtils} from "contracts/utils/VeloSwapUtils.sol";
import {IVeloPool} from "contracts/interfaces/velodrome/IVeloPool.sol";
import {IVeloRouter} from "contracts/interfaces/velodrome/IVeloRouter.sol";


contract Setup is Test {
    using SafeERC20 for IERC20;

    BeefyVaultConcLiq vault;
    BeefyVaultConcLiqFactory vaultFactory;
    StrategyPassiveManagerVelodrome strategy;
    StrategyPassiveManagerVelodrome implementation;
    BeefyRewardPoolFactory rewardPoolFactory;
    BeefyRewardPool rewardPool;
    StrategyFactory factory;

    address constant pool = 0x4360027009C551970635f2b6DBFaBb2441A36A3e;
    address constant gauge = 0x27CE222708360C62AE3dcc66E98A25A662c03F75;
    address constant nftManager = 0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4;

    address constant token0 = 0x4200000000000000000000000000000000000006;
    address constant token1 = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address constant output = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    address constant native = 0x4200000000000000000000000000000000000006;

    address constant strategist = 0xb2e4A61D99cA58fB8aaC58Bb2F8A59d63f552fC0;
    address constant beefyFeeRecipient = 0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B;
    address constant beefyFeeConfig = 0x216EEE15D1e3fAAD34181f66dd0B665f556a638d;
    address constant unirouter = 0xF132bdb9573867cD72f2585C338B923F973EB817;
    address constant quoter = 0xA2DEcF05c16537C702779083Fe067e308463CE45;
    address constant keeper = 0x4fED5491693007f0CD49f4614FFC38Ab6A04B619;
    int24 constant width = 500;

    address constant user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;

    uint token0Size = 1 ether;
    uint token1Size = 20000e18;
    
    bytes rewardPath;
    bytes tradePath;
    bytes path0;
    bytes path1;

    function setUp() public {

        // Deploy Contracts
        BeefyVaultConcLiq vaultImplementation = new BeefyVaultConcLiq();
        vaultFactory = new BeefyVaultConcLiqFactory(address(vaultImplementation));
        vault = vaultFactory.cloneVault();

        implementation = new StrategyPassiveManagerVelodrome();
        factory = new StrategyFactory(native, keeper, beefyFeeRecipient, beefyFeeConfig);

        BeefyRewardPool rewardPoolImplementation = new BeefyRewardPool();
        rewardPoolFactory = new BeefyRewardPoolFactory(address(rewardPoolImplementation));
        rewardPool = rewardPoolFactory.cloneRewardPool();

        rewardPool.initialize(address(vault), "rCowVeloETH-USDC", "rCowVeloETH-USDC");
        
        // Set up routing for trade paths

        address[] memory tradeRoute = new address[](2);
        tradeRoute[0] = token0;
        tradeRoute[1] = token1;

        address[] memory rewardRoute = new address[](2);
        rewardRoute[0] = output;
        rewardRoute[1] = native;

        uint24[] memory rewardSpacing = new uint24[](1);
        rewardSpacing[0] = 200;

        uint24[] memory tradeSpacing = new uint24[](1);
        tradeSpacing[0] = 200;

        rewardPath = routeToPath(rewardRoute, rewardSpacing);
        path0 = "0x";
        path1 = "0x";
        tradePath = routeToPath(tradeRoute, tradeSpacing);

        // Init the the strategy and vault
        StratFeeManagerInitializable.CommonAddresses memory commonAddresses = StratFeeManagerInitializable.CommonAddresses(
            address(vault),
            unirouter,
            strategist,
            address(factory)
        );

        factory.addStrategy("StrategyPassiveManagerVelodrome_v1", address(implementation));

        factory.addRebalancer(user);

        bytes[] memory paths = new bytes[](3);
        paths[0] = rewardPath;
        paths[1] = path0;
        paths[2] = path1;
       
        address _strategy = factory.createStrategy("StrategyPassiveManagerVelodrome_v1");
        strategy = StrategyPassiveManagerVelodrome(_strategy);
        strategy.initialize(
            pool, 
            quoter,
            nftManager,
            gauge,
            address(rewardPool),
            output,
            width,
            paths, 
            commonAddresses
        );

        rewardPool.setWhitelist(address(strategy), true);

        vault.initialize(address(strategy), "Moo Vault", "mooVault");

        strategy.setDeviation(100);

        address _want = vault.want();
        assertEq(_want, pool);

        address[] memory outputRoute = strategy.outputToNative();
        assertEq(outputRoute.length, 2);
        assertEq(outputRoute[0], output);
        assertEq(outputRoute[1], native);
    }

    function routeToPath(
        address[] memory _route,
        uint24[] memory _fee
    ) internal pure returns (bytes memory path) {
        path = abi.encodePacked(_route[0]);
        uint256 feeLength = _fee.length;
        for (uint256 i = 0; i < feeLength; i++) {
            path = abi.encodePacked(path, _fee[i], _route[i+1]);
        }
    }
}