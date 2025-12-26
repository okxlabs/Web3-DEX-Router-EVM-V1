// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/BaseTestSetup.t.sol";

contract CommissionDualTests is BaseTestSetup {
    // V2测试
    // 测试单跳ERC20-ERC20，目标代币分佣
    function testCommissionToToken() public {
        // 1. 准备测试参数
        uint256 sourceTokenIndex = 1;
        uint256 targetTokenIndex = 2;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV2Pair pair = IUniswapV2Pair(
            pairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log(
            "before sourceToken balance:%s",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before targetToken balance:%s",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            false
        );

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        // 2. 使用_buildCommissionInfoUnified函数生成佣金信息
        bytes memory generated_commission = _buildCommissionInfoUnified(
            false, // 不从源代币收取
            true, // 从目标代币收取
            address(tokens[targetTokenIndex]), // 目标代币作为佣金代币
            200, // 0.2%，对应十六进制0x012c
            refererAddress,
            100, // 0.1%，对应十六进制0x012c
            refererAddress2, // 存在双分佣
            false
        );

        // 输出生成的佣金信息
        console2.log("Generated commission info:");
        console2.logBytes(generated_commission);

        // 3. 构建调用数据
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.unxswapExactOutTo.selector,
            uint256(uint160(address(tokens[sourceTokenIndex]))),
            amountOut,
            amountInMax,
            amy,
            pools
        );
        bytes memory data = bytes.concat(pre_data, generated_commission);

        // 6. 执行交易
        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "referer commission:",
            tokens[targetTokenIndex].balanceOf(refererAddress)
        );
        console2.log(
            "referer2 commission:",
            tokens[targetTokenIndex].balanceOf(refererAddress2)
        );
    }

    // 测试单跳ERC20-ERC20，源代币分佣
    function testCommissionFromToken() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 1;
        uint256 targetTokenIndex = 2;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV2Pair pair = IUniswapV2Pair(
            pairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "referer1 balance:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );
        console2.log(
            "referer2 balance:",
            tokens[sourceTokenIndex].balanceOf(refererAddress2)
        );

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            false
        );

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从源代币收取
        address refererAddress = makeAddr("referer"); // 创建一个接收佣金的地址
        bytes memory commission = _buildCommissionInfoUnified(
            true, // 从源代币收取
            false, // 不从目标代币收取
            address(tokens[sourceTokenIndex]),
            200, // 0.3%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission from source token:");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.unxswapExactOutTo.selector,
            uint256(uint160(address(tokens[sourceTokenIndex]))),
            amountOut,
            amountInMax,
            amy,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after sourceToken balance pool1:",
            tokens[sourceTokenIndex].balanceOf(address(pair))
        );
        console2.log(
            "referer1 commission:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );
        console2.log(
            "referer2 commission:",
            tokens[sourceTokenIndex].balanceOf(refererAddress2)
        );
    }

    // 测试单跳ETH-ERC20，目标代币分佣
    function testCommissionToTokenWithETHSource() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 0; // ETH
        uint256 targetTokenIndex = 1;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV2Pair pair = IUniswapV2Pair(
            pairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(ETH));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            false
        );

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从目标代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            false, // 不从源代币收取
            true, // 从目标代币收取
            address(tokens[targetTokenIndex]),
            200, // 0.3%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission to target token:");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.unxswapExactOutTo.selector,
            uint256(uint160(ETH)),
            amountOut,
            amountInMax,
            amy,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        (bool success, ) = address(dexRouter).call{value: amountInMax}(
            data
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "referer commission:",
            tokens[targetTokenIndex].balanceOf(refererAddress)
        );
    }

    // 测试单跳ERC20-ETH，目标代币分佣
    function testCommissionToTokenWithETHTarget() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 1;
        uint256 targetTokenIndex = 0; // ETH
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV2Pair pair = IUniswapV2Pair(
            pairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("middleToken:", address(tokens[targetTokenIndex]));
        console2.log("targetToken:", address(ETH));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before middleToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("before targetToken balance:", amy.balance);

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            true
        );

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从目标代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            false, // 不从源代币收取
            true, // 从目标代币收取
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), // ETH作为佣金代币
            200, // 0.3%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission to target token (ETH):");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.unxswapExactOutTo.selector,
            uint256(uint160(address(tokens[sourceTokenIndex]))),
            amountOut,
            amountInMax,
            amy,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after middleToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("after targetToken balance:", amy.balance);
        console2.log("referer commission:", refererAddress.balance);
    }

    // 测试单跳ETH-ERC20，源代币分佣
    function testCommissionFromTokenWithETHSource() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 0; // ETH
        uint256 targetTokenIndex = 1;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV2Pair pair = IUniswapV2Pair(
            pairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(ETH));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            false
        );

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从源代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            true, // 从源代币收取
            false, // 不从目标代币收取
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), // ETH作为佣金代币
            200, // 0.3%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission from source token (ETH):");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.unxswapExactOutTo.selector,
            uint256(uint160(ETH)),
            amountOut,
            amountInMax,
            amy,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        (bool success, ) = address(dexRouter).call{value: amountInMax}(
            data
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("referer commission:", refererAddress.balance);
    }

    // 测试单跳ERC20-ETH，源代币分佣
    function testCommissionFromTokenWithETHTarget() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 1;
        uint256 targetTokenIndex = 0; // ETH
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV2Pair pair = IUniswapV2Pair(
            pairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("targetToken:", address(ETH));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log("before targetToken balance:", amy.balance);

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            true
        );

        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从源代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            true, // 从源代币收取
            false, // 不从目标代币收取
            address(tokens[sourceTokenIndex]),
            200, // 0.3%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission from source token:");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.unxswapExactOutTo.selector,
            uint256(uint160(address(tokens[sourceTokenIndex]))),
            amountOut,
            amountInMax,
            amy,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log("after targetToken balance:", amy.balance);
        console2.log(
            "referer commission:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );
    }

    // 测试多跳ERC20-ERC20，目标代币分佣
    function testCommissionToTokenMultiPool() public {
        uint256 sourceTokenIndex = 1;
        uint256 middleTokenIndex = 2;
        uint256 targetTokenIndex = 3;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 600e18;
        address refererAddress = address(0x123);

        // 直接使用pairMatrix[1][2]和pairMatrix[2][3]，不创建局部变量
        console2.log("pair12:", address(pairMatrix[1][2]));
        console2.log("pair23:", address(pairMatrix[2][3]));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("middleToken:", address(tokens[middleTokenIndex]));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before referer balance:",
            tokens[targetTokenIndex].balanceOf(refererAddress)
        );

        // 创建pools数组并直接填充，不使用中间变量
        bytes32[] memory pools = new bytes32[](2);
        pools[0] = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[middleTokenIndex]),
            address(pairMatrix[1][2]),
            false
        );
        pools[1] = _buildPool(
            address(tokens[middleTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pairMatrix[2][3]),
            false
        );

        // 内联构建调用数据
        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));

        // 直接构建并连接数据，不使用中间变量
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.unxswapExactOutTo.selector,
                    uint256(uint160(address(tokens[sourceTokenIndex]))),
                    amountOut,
                    amountInMax,
                    amy,
                    pools
                ),
                _buildCommissionInfoUnified(
                    false, // 不从源代币收取
                    true, // 从目标代币收取
                    address(tokens[targetTokenIndex]),
                    200, // 0.3%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after referer balance:",
            tokens[targetTokenIndex].balanceOf(refererAddress)
        );
    }

    // 测试多跳ERC20-ERC20，源代币分佣
    function testCommissionFromTokenMultiPool() public {
        uint256 sourceTokenIndex = 1;
        uint256 middleTokenIndex = 2;
        uint256 targetTokenIndex = 3;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 600e18;
        address refererAddress = address(0x123);

        // 直接使用pairMatrix，不创建局部变量
        console2.log("pair12:", address(pairMatrix[1][2]));
        console2.log("pair23:", address(pairMatrix[2][3]));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("middleToken:", address(tokens[middleTokenIndex]));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before referer balance:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );

        // 创建pools数组并直接填充
        bytes32[] memory pools = new bytes32[](2);
        pools[0] = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[middleTokenIndex]),
            address(pairMatrix[1][2]),
            false
        );
        pools[1] = _buildPool(
            address(tokens[middleTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pairMatrix[2][3]),
            false
        );

        // 内联构建调用数据
        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );

        // 直接构建并连接数据
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.unxswapExactOutTo.selector,
                    uint256(uint160(address(tokens[sourceTokenIndex]))),
                    amountOut,
                    amountInMax,
                    amy,
                    pools
                ),
                _buildCommissionInfoUnified(
                    true, // 从源代币收取
                    false, // 不从目标代币收取
                    address(tokens[sourceTokenIndex]),
                    200, // 0.3%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after referer balance:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );
    }

    // 测试多跳ETH-ERC20，目标代币分佣
    function testCommissionToTokenMultiPoolWithETHSource() public {
        uint256 sourceTokenIndex = 0; // ETH/WETH
        uint256 middleTokenIndex = 1;
        uint256 targetTokenIndex = 2;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 600e18;
        address refererAddress = address(0x123);

        // 直接使用pairMatrix，不创建局部变量
        console2.log("pair01:", address(pairMatrix[0][1]));
        console2.log("pair12:", address(pairMatrix[1][2]));
        console2.log("sourceToken:", address(ETH));
        console2.log("middleToken:", address(tokens[middleTokenIndex]));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log(
            "before middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before referer balance:",
            tokens[targetTokenIndex].balanceOf(refererAddress)
        );

        // 创建pools数组并直接填充
        bytes32[] memory pools = new bytes32[](2);
        pools[0] = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[middleTokenIndex]),
            address(pairMatrix[0][1]),
            false
        );
        pools[1] = _buildPool(
            address(tokens[middleTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pairMatrix[1][2]),
            false
        );

        // 内联构建调用数据
        vm.startPrank(amy);
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));

        // 直接构建并连接数据
        (bool success, ) = address(dexRouter).call{value: amountInMax}(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.unxswapExactOutTo.selector,
                    uint256(uint160(ETH)),
                    amountOut,
                    amountInMax,
                    amy,
                    pools
                ),
                _buildCommissionInfoUnified(
                    false, // 不从源代币收取
                    true, // 从目标代币收取
                    address(tokens[targetTokenIndex]),
                    200, // 0.3%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log(
            "after middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after referer balance:",
            tokens[targetTokenIndex].balanceOf(refererAddress)
        );
    }

    // 测试多跳ETH-ERC20，源代币分佣
    function testCommissionFromTokenMultiPoolWithETHSource() public {
        uint256 sourceTokenIndex = 0; // ETH/WETH
        uint256 middleTokenIndex = 1;
        uint256 targetTokenIndex = 2;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 600e18;
        address refererAddress = address(0x123);

        // 直接使用pairMatrix，不创建局部变量
        console2.log("pair01:", address(pairMatrix[0][1]));
        console2.log("pair12:", address(pairMatrix[1][2]));
        console2.log("sourceToken:", address(ETH));
        console2.log("middleToken:", address(tokens[middleTokenIndex]));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log(
            "before middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("before referer balance:", refererAddress.balance);

        // 创建pools数组并直接填充
        bytes32[] memory pools = new bytes32[](2);
        pools[0] = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[middleTokenIndex]),
            address(pairMatrix[0][1]),
            false
        );
        pools[1] = _buildPool(
            address(tokens[middleTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pairMatrix[1][2]),
            false
        );

        // 内联构建调用数据
        vm.startPrank(amy);
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));

        // 直接构建并连接数据
        (bool success, ) = address(dexRouter).call{value: amountInMax}(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.unxswapExactOutTo.selector,
                    uint256(uint160(ETH)),
                    amountOut,
                    amountInMax,
                    amy,
                    pools
                ),
                _buildCommissionInfoUnified(
                    true, // 从源代币收取
                    false, // 不从目标代币收取
                    // address(tokens[sourceTokenIndex]),
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    200, // 0.3%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log(
            "after middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("after referer balance:", refererAddress.balance);
    }

    // 测试多跳ERC20-ETH，目标代币分佣
    function testCommissionToTokenMultiPoolWithETHTarget() public {
        uint256 sourceTokenIndex = 1;
        uint256 middleTokenIndex = 2;
        uint256 targetTokenIndex = 0; // ETH/WETH
        uint256 amountOut = 400e18;
        uint256 amountInMax = 600e18;
        address refererAddress = address(0x123);

        // 直接使用pairMatrix，不创建局部变量
        console2.log("pair12:", address(pairMatrix[1][2]));
        console2.log("pair20:", address(pairMatrix[2][0]));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("middleToken:", address(tokens[middleTokenIndex]));
        console2.log("targetToken:", address(ETH));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log("before targetToken balance:", amy.balance);
        console2.log("before referer balance:", refererAddress.balance);

        // 创建pools数组并直接填充
        bytes32[] memory pools = new bytes32[](2);
        pools[0] = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[middleTokenIndex]),
            address(pairMatrix[1][2]),
            false
        );
        pools[1] = _buildPool(
            address(tokens[middleTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pairMatrix[2][0]),
            true
        );

        // 内联构建调用数据
        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));

        // 直接构建并连接数据
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.unxswapExactOutTo.selector,
                    uint256(uint160(address(tokens[sourceTokenIndex]))),
                    amountOut,
                    amountInMax,
                    amy,
                    pools
                ),
                _buildCommissionInfoUnified(
                    false, // 不从源代币收取
                    true, // 从目标代币收取
                    address(COMMISSION_ETH),
                    200, // 0.3%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log("after targetToken balance:", amy.balance);
        console2.log("after referer balance:", refererAddress.balance);
    }

    // 测试多跳ERC20-ETH，源代币分佣
    function testCommissionFromTokenMultiPoolWithETHTarget() public {
        uint256 sourceTokenIndex = 1;
        uint256 middleTokenIndex = 2;
        uint256 targetTokenIndex = 0; // ETH/WETH
        uint256 amountOut = 400e18;
        uint256 amountInMax = 600e18;
        address refererAddress = address(0x123);

        // 直接使用pairMatrix，不创建局部变量
        console2.log("pair12:", address(pairMatrix[1][2]));
        console2.log("pair20:", address(pairMatrix[2][0]));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("middleToken:", address(tokens[middleTokenIndex]));
        console2.log("targetToken:", address(ETH));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log("before targetToken balance:", amy.balance);
        console2.log(
            "before referer balance:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );

        // 创建pools数组并直接填充
        bytes32[] memory pools = new bytes32[](2);
        pools[0] = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[middleTokenIndex]),
            address(pairMatrix[1][2]),
            false
        );
        pools[1] = _buildPool(
            address(tokens[middleTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pairMatrix[2][0]),
            true
        );

        // 内联构建调用数据
        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));

        // 直接构建并连接数据
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.unxswapExactOutTo.selector,
                    uint256(uint160(address(tokens[sourceTokenIndex]))),
                    amountOut,
                    amountInMax,
                    amy,
                    pools
                ),
                _buildCommissionInfoUnified(
                    true, // 从源代币收取
                    false, // 不从目标代币收取
                    address(tokens[sourceTokenIndex]),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after middleToken balance:",
            tokens[middleTokenIndex].balanceOf(amy)
        );
        console2.log("after targetToken balance:", amy.balance);
        console2.log(
            "after referer balance:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );
    }

    // V3测试
    // 测试单跳ERC20-ERC20，目标代币分佣
    function testCommissionToTokenV3WithERC20Source() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("pair23:", address(v3PairMatrix[2][3]));
        console2.log("sourceToken:", address(tokens[1]));
        console2.log("middleToken:", address(tokens[2]));
        console2.log("targetToken:", address(tokens[3]));
        console2.log("before sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("before middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("before targetToken balance:", tokens[3].balanceOf(amy));

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );
        pools[1] = uint256(
            _buildPool(
                address(tokens[2]),
                address(tokens[3]),
                address(v3PairMatrix[2][3]),
                false
            )
        );

        vm.startPrank(amy);
        tokens[1].approve(address(tokenApprove), 500e18);
        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    false, // 从源代币收取
                    true, // 不从目标代币收取
                    address(tokens[3]),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("after middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[3].balanceOf(amy));
        console2.log(
            "referer commission:",
            tokens[3].balanceOf(refererAddress)
        );
    }

    // 测试单跳ERC20-ERC20，源代币分佣
    function testCommissionFromTokenV3WithERC20Source() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("pair23:", address(v3PairMatrix[2][3]));
        console2.log("sourceToken:", address(tokens[1]));
        console2.log("middleToken:", address(tokens[2]));
        console2.log("targetToken:", address(tokens[3]));
        console2.log("before sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("before middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("before targetToken balance:", tokens[3].balanceOf(amy));

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );
        pools[1] = uint256(
            _buildPool(
                address(tokens[2]),
                address(tokens[3]),
                address(v3PairMatrix[2][3]),
                false
            )
        );

        vm.startPrank(amy);
        tokens[1].approve(address(tokenApprove), 500e18);
        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    true, // 从源代币收取
                    false, // 不从目标代币收取
                    address(tokens[1]),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("after middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[3].balanceOf(amy));
        console2.log(
            "referer commission:",
            tokens[3].balanceOf(refererAddress)
        );
    }

    // 测试单跳ETH-ERC20，目标代币分佣
    function testCommissionToTokenV3WithETHSource() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 0; // ETH
        uint256 targetTokenIndex = 1;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV3Pool pair = IUniswapV3Pool(
            v3PairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(ETH));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            false
        );

        uint256[] memory pools = new uint256[](1);
        pools[0] = uint256(pool0);

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从目标代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            false, // 不从源代币收取
            true, // 从目标代币收取
            address(tokens[targetTokenIndex]),
            200, // 0.2%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission to target token:");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.uniswapV3SwapExactOutTo.selector,
            uint256(uint160(address(amy))),
            amountOut,
            amountInMax,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        console2.log("Pool address:", address(pair));
        (bool success, ) = address(dexRouter).call{value: amountInMax}(
            data
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log(
            "referer commission:",
            tokens[targetTokenIndex].balanceOf(refererAddress)
        );
    }

    // 测试单跳ERC20-ETH，目标代币分佣
    function testCommissionToTokenV3WithETHTarget() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 1;
        uint256 targetTokenIndex = 0; // ETH
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV3Pool pair = IUniswapV3Pool(
            v3PairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("middleToken:", address(tokens[targetTokenIndex]));
        console2.log("targetToken:", address(ETH));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "before middleToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("before targetToken balance:", amy.balance);

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            true
        );

        uint256[] memory pools = new uint256[](1);
        // 将pool0转换为uint256类型，并设置WETH_UNWRAP_MASK标志
        pools[0] = uint256(pool0) | _WETH_UNWRAP_MASK;

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从目标代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            false, // 不从源代币收取
            true, // 从目标代币收取
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), // ETH作为佣金代币
            200, // 0.2%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission to target token (ETH):");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.uniswapV3SwapExactOutTo.selector,
            uint256(uint160(address(amy))),
            amountOut,
            amountInMax,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        console2.log("Pool address:", address(pair));
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log(
            "after middleToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("after targetToken balance:", amy.balance);
        console2.log("referer commission:", refererAddress.balance);
    }

    // 测试单跳ETH-ERC20，源代币分佣
    function testCommissionFromTokenV3WithETHSource() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 0; // ETH
        uint256 targetTokenIndex = 1;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV3Pool pair = IUniswapV3Pool(
            v3PairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(ETH));
        console2.log("targetToken:", address(tokens[targetTokenIndex]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log(
            "before targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            false
        );

        uint256[] memory pools = new uint256[](1);
        pools[0] = uint256(pool0);

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从源代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            true, // 从源代币收取
            false, // 不从目标代币收取
            address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), // ETH作为佣金代币
            200, // 0.2%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission from source token (ETH):");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.uniswapV3SwapExactOutTo.selector,
            uint256(uint160(address(amy))),
            amountOut,
            amountInMax,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        console2.log("Pool address:", address(pair));
        (bool success, ) = address(dexRouter).call{value: amountInMax}(
            data
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log(
            "after targetToken balance:",
            tokens[targetTokenIndex].balanceOf(amy)
        );
        console2.log("referer commission:", refererAddress.balance);
    }

    // 测试单跳ERC20-ETH，源代币分佣
    function testCommissionFromTokenV3WithETHTarget() public {
        // 准备测试参数
        uint256 sourceTokenIndex = 1;
        uint256 targetTokenIndex = 0; // ETH
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;
        IUniswapV3Pool pair = IUniswapV3Pool(
            v3PairMatrix[sourceTokenIndex][targetTokenIndex]
        );

        console2.log("pair:", address(pair));
        console2.log("sourceToken:", address(tokens[sourceTokenIndex]));
        console2.log("targetToken:", address(ETH));
        console2.log(
            "before sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log("before targetToken balance:", amy.balance);

        // 构建pool数据
        bytes32 pool0 = _buildPool(
            address(tokens[sourceTokenIndex]),
            address(tokens[targetTokenIndex]),
            address(pair),
            true
        );

        uint256[] memory pools = new uint256[](1);
        // 将pool0转换为uint256类型，并设置WETH_UNWRAP_MASK标志
        pools[0] = uint256(pool0) | _WETH_UNWRAP_MASK;

        // 使用_buildCommissionInfoUnified函数生成佣金信息 - 从源代币收取
        address refererAddress = makeAddr("referer");
        bytes memory commission = _buildCommissionInfoUnified(
            true, // 从源代币收取
            false, // 不从目标代币收取
            address(tokens[sourceTokenIndex]),
            200, // 0.2%的佣金率
            refererAddress,
            100,
            refererAddress2,
            false
        );

        console2.log("Commission from source token:");
        console2.logBytes(commission);

        // 构建调用数据并执行交易
        bytes memory pre_data = abi.encodeWithSelector(
            DexRouter.uniswapV3SwapExactOutTo.selector,
            uint256(uint160(address(amy))),
            amountOut,
            amountInMax,
            pools
        );
        bytes memory data = bytes.concat(pre_data, commission);

        vm.startPrank(amy);
        tokens[sourceTokenIndex].approve(address(tokenApprove), UINT256_MAX);
        console2.log("Approved tokenApprove:", address(tokenApprove));
        console2.log(
            "Approval amount:",
            tokens[sourceTokenIndex].allowance(amy, address(tokenApprove))
        );
        console2.log("Amy address:", amy);
        console2.log("DexRouter address:", address(dexRouter));
        console2.log("Pool address:", address(pair));
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        vm.stopPrank();

        console2.log(
            "after sourceToken balance:",
            tokens[sourceTokenIndex].balanceOf(amy)
        );
        console2.log("after targetToken balance:", amy.balance);
        console2.log(
            "referer commission:",
            tokens[sourceTokenIndex].balanceOf(refererAddress)
        );
    }

    // 测试多跳ERC20-ERC20，源代币分佣
    function testCommissionMultiPoolsToTokenV3WithERC20Source() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("pair23:", address(v3PairMatrix[2][3]));
        console2.log("sourceToken:", address(tokens[1]));
        console2.log("middleToken:", address(tokens[2]));
        console2.log("targetToken:", address(tokens[3]));
        console2.log("before sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("before middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("before targetToken balance:", tokens[3].balanceOf(amy));
        console2.log(
            "before referer balance:",
            tokens[1].balanceOf(address(0x123))
        );

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );
        pools[1] = uint256(
            _buildPool(
                address(tokens[2]),
                address(tokens[3]),
                address(v3PairMatrix[2][3]),
                false
            )
        );

        vm.startPrank(amy);
        tokens[1].approve(address(tokenApprove), type(uint256).max);

        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    true, // 从源代币收取
                    false, // 不从目标代币收取
                    address(tokens[1]),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("after middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[3].balanceOf(amy));
        console2.log(
            "after referer balance:",
            tokens[1].balanceOf(address(0x123))
        );
    }

    // 测试多跳ERC20-ERC20，目标代币分佣
    function testCommissionMultiPoolsFromTokenV3WithERC20Target() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("pair23:", address(v3PairMatrix[2][3]));
        console2.log("sourceToken:", address(tokens[1]));
        console2.log("middleToken:", address(tokens[2]));
        console2.log("targetToken:", address(tokens[3]));
        console2.log("before sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("before middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("before targetToken balance:", tokens[3].balanceOf(amy));
        console2.log(
            "before referer balance:",
            tokens[3].balanceOf(address(0x123))
        );

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );
        pools[1] = uint256(
            _buildPool(
                address(tokens[2]),
                address(tokens[3]),
                address(v3PairMatrix[2][3]),
                false
            )
        );

        vm.startPrank(amy);
        tokens[1].approve(address(tokenApprove), type(uint256).max);

        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    false, // 不从源代币收取
                    true, // 从目标代币收取
                    address(tokens[3]),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("after middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[3].balanceOf(amy));
        console2.log(
            "after referer balance:",
            tokens[3].balanceOf(address(0x123))
        );
    }

    // 测试多跳ETH-ERC20，目标代币分佣
    function testCommissionMultiPoolsToTokenV3WithETHTarget() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair01:", address(v3PairMatrix[0][1]));
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("sourceToken:", address(ETH));
        console2.log("middleToken:", address(tokens[1]));
        console2.log("targetToken:", address(tokens[2]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log("before middleToken balance:", tokens[1].balanceOf(amy));
        console2.log("before targetToken balance:", tokens[2].balanceOf(amy));
        console2.log(
            "before referer balance:",
            tokens[2].balanceOf(address(0x123))
        );

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[0]),
                address(tokens[1]),
                address(v3PairMatrix[0][1]),
                false
            )
        );
        pools[1] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );

        vm.startPrank(amy);

        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call{value: 500e18}(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    false, // 不从源代币收取
                    true, // 从目标代币收取
                    address(tokens[2]),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log("after middleToken balance:", tokens[1].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[2].balanceOf(amy));
        console2.log(
            "after referer balance:",
            tokens[2].balanceOf(address(0x123))
        );
    }

    // 测试多跳ETH-ERC20，源代币分佣
    function testCommissionMultiPoolsToTokenV3WithETHSouce() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair01:", address(v3PairMatrix[0][1]));
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("sourceToken:", address(ETH));
        console2.log("middleToken:", address(tokens[1]));
        console2.log("targetToken:", address(tokens[2]));
        console2.log("before sourceToken balance:", amy.balance);
        console2.log("before middleToken balance:", tokens[1].balanceOf(amy));
        console2.log("before targetToken balance:", tokens[2].balanceOf(amy));
        console2.log(
            "before referer balance:",
            tokens[2].balanceOf(address(0x123))
        );

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[0]),
                address(tokens[1]),
                address(v3PairMatrix[0][1]),
                false
            )
        );
        pools[1] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );

        vm.startPrank(amy);

        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call{value: 500e18}(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    true, //   从源代币收取
                    false, // 不从目标代币收取
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log("after middleToken balance:", tokens[1].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[2].balanceOf(amy));
        console2.log(
            "after referer balance:",
            tokens[2].balanceOf(address(0x123))
        );
    }

    // 测试多跳ERC20-ETH，目标代币分佣
    function testCommissionMultiPoolsFromTokenV3WithETHTarget() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("pair20:", address(v3PairMatrix[2][0]));
        console2.log("sourceToken:", address(tokens[1]));
        console2.log("middleToken:", address(tokens[2]));
        console2.log("targetToken:", address(tokens[0]));
        console2.log("before sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("before middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("before targetToken balance:", amy.balance);
        console2.log(
            "before referer balance:",
            tokens[1].balanceOf(address(0x123))
        );

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );
        pools[1] =
            uint256(
                _buildPool(
                    address(tokens[2]),
                    address(tokens[0]),
                    address(v3PairMatrix[2][0]),
                    true
                )
            ) |
            _WETH_UNWRAP_MASK;

        vm.startPrank(amy);
        tokens[1].approve(address(tokenApprove), 500e18);
        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    false, // 不从源代币收取
                    true, // 从目标代币收取
                    address(COMMISSION_ETH),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log("after middleToken balance:", tokens[1].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[2].balanceOf(amy));
        console2.log(
            "after referer balance:",
            tokens[2].balanceOf(address(0x123))
        );
    }

    // 测试多跳ERC20-ETH，源代币分佣
    function testCommissionMultiPoolsFromTokenV3WithETHSouce() public {
        // 使用更少的局部变量，直接使用常量值
        console2.log("pair12:", address(v3PairMatrix[1][2]));
        console2.log("pair20:", address(v3PairMatrix[2][0]));
        console2.log("sourceToken:", address(tokens[1]));
        console2.log("middleToken:", address(tokens[2]));
        console2.log("targetToken:", address(tokens[0]));
        console2.log("before sourceToken balance:", tokens[1].balanceOf(amy));
        console2.log("before middleToken balance:", tokens[2].balanceOf(amy));
        console2.log("before targetToken balance:", amy.balance);
        console2.log(
            "before referer balance:",
            tokens[1].balanceOf(address(0x123))
        );

        // 直接创建pools数组并填充，不使用任何中间变量
        uint256[] memory pools = new uint256[](2);
        pools[0] = uint256(
            _buildPool(
                address(tokens[1]),
                address(tokens[2]),
                address(v3PairMatrix[1][2]),
                false
            )
        );
        pools[1] =
            uint256(
                _buildPool(
                    address(tokens[2]),
                    address(tokens[0]),
                    address(v3PairMatrix[2][0]),
                    true
                )
            ) |
            _WETH_UNWRAP_MASK;

        vm.startPrank(amy);
        tokens[1].approve(address(tokenApprove), 500e18);
        // 完全内联所有操作，减少栈使用
        (bool success, ) = address(dexRouter).call(
            bytes.concat(
                abi.encodeWithSelector(
                    dexRouter.uniswapV3SwapExactOutTo.selector,
                    uint256(uint160(amy)),
                    400e18,
                    500e18,
                    pools
                ),
                _buildCommissionInfoUnified(
                    true, // 从源代币收取
                    false, // 不从目标代币收取
                    address(tokens[1]),
                    200, // 0.2%的佣金率
                    refererAddress,
                    100,
                    refererAddress2,
                    false
                )
            )
        );
        require(success, "call failed");
        vm.stopPrank();

        console2.log("after sourceToken balance:", amy.balance);
        console2.log("after middleToken balance:", tokens[1].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[2].balanceOf(amy));
        console2.log(
            "after referer balance:",
            tokens[2].balanceOf(address(0x123))
        );
    }
}
