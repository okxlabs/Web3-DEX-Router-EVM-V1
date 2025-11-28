const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
const { isZkSyncNetwork, buildZkWallet } = require('../scripts/utils/zksync');

const getDeployedDir = (network) =>
  network === 'zksync' ? 'zkSyncEra' : network;

task("deploy-upgrade", "Deploys and upgrades the DEX contract")
  .setAction(async (taskArgs, hre) => {
    try {
      const network = hre.network.name;
      const isZkSync = isZkSyncNetwork(hre, network);

      // Check balance first
      let deployerAddress;
      let balance;
      if (isZkSync) {
        const wallet = buildZkWallet(hre, network);
        deployerAddress = wallet.address;
        balance = await wallet.getBalance();
      } else {
        const [deployer] = await hre.ethers.getSigners();
        deployerAddress = deployer.address;
        balance = await hre.ethers.provider.getBalance(deployer.address);
      }
      const balanceInEth = hre.ethers.utils.formatEther(balance);

      console.log(`Deployer address: ${deployerAddress}`);
      console.log(`Balance: ${balanceInEth} ${network === 'bsc' ? 'BNB' : 'ETH'}`);

      // Step 0: Clean
      await hre.run("clean");

      // Step 1: Git operations - Save current state
      console.log("\nStep 1: Saving current state...");
      await execPromise('git add contracts/8/libraries/CommonUtils.sol contracts/8/UnxswapV3Router.sol');

      // Step 2: Run ureplace.js
      console.log("\nStep 2: Running ureplace.js...");

      await hre.run("run", {
        script: "scripts/tools/ureplace.js",
        network: network
      });
      await hre.run("compile");

      // Step 3: Deploy new implementation
      console.log("\nStep 3: Deploying new implementation...");

      const deployDexImp = require('../scripts/deploy_dex_imp');
      const newDexRouterAddress = await deployDexImp();

      if (!newDexRouterAddress) {
        throw new Error("Could not get newly deployed dexRouter address");
      }

      // Step 4: Update base.js with new implementation address
      console.log("\nStep 4: Updating implementation address...");
      const deployedDir = getDeployedDir(network);
      const baseBasePath = path.join(process.cwd(), 'scripts/deployed/' + deployedDir + '/base.js');
      let baseContent = fs.readFileSync(baseBasePath, 'utf8');

      baseContent = baseContent.replace(
        /newImpl:\s*["'].*["']/,
        `newImpl: "${newDexRouterAddress}"`
      );

      fs.writeFileSync(baseBasePath, baseContent);
      console.log(`Updated newImpl address to: ${newDexRouterAddress}`);

      if (network === 'zeta') {
        // step 5: verify contract for zeta
        console.log("\nStep 5: verifying contract for zeta")
        await hre.run("run", {
          script: "scripts/verify_zeta.js",
          network: network
        })
      } else {
        // Step 5: Verify contracts
        console.log("\nStep 5: Verifying contracts...");
        await hre.run("run", {
          script: "scripts/verify_etherscan_oklink.js",
          network: network
        });
      }




      // Step 6: Restore original files
      console.log("\nStep 6: Restoring original files...");
      await execPromise('git checkout -- contracts/8/libraries/CommonUtils.sol contracts/8/UnxswapV3Router.sol');

      console.log("\nDeployment and upgrade process completed successfully!");
    } catch (error) {
      console.error("Error during deployment:", error);

    }
  })

  task("deploy-upgrade-exactout", "Deploys and upgrades the DEX EXACTOUT contract")
  .setAction(async (taskArgs, hre) => {
    try {
      const network = hre.network.name;
      const isZkSync = isZkSyncNetwork(hre, network);

      // Check balance first
      let deployerAddress;
      let balance;
      if (isZkSync) {
        const wallet = buildZkWallet(hre, network);
        deployerAddress = wallet.address;
        balance = await wallet.getBalance();
      } else {
        const [deployer] = await hre.ethers.getSigners();
        deployerAddress = deployer.address;
        balance = await hre.ethers.provider.getBalance(deployer.address);
      }
      const balanceInEth = hre.ethers.utils.formatEther(balance);

      console.log(`Deployer address: ${deployerAddress}`);
      console.log(`Balance: ${balanceInEth} ${network === 'bsc' ? 'BNB' : 'ETH'}`);

      if (parseFloat(balanceInEth) < 0.001) {
        throw new Error(`Insufficient balance. Need at least 0.01 ${network === 'bsc' ? 'BNB' : 'ETH'} to deploy`);
      }

      // Step 0: Clean
      await hre.run("clean");

      // Step 1: Git operations - Save current state
      console.log("\nStep 1: Saving current state...");
      await execPromise('git add contracts/8/libraries/CommonUtils.sol contracts/8/UnxswapV3Router.sol');

      // Step 2: Run ureplace.js
      console.log("\nStep 2: Running ureplace.js...");

      await hre.run("run", {
        script: "scripts/tools/ureplace.js",
        network: network
      });
      await hre.run("compile");

      // Step 3: Deploy new implementation
      console.log("\nStep 3: Deploying new implementation...");

      const deployDexImp = require('../scripts/deploy_dex_exactout_imp');
      const newDexRouterAddress = await deployDexImp();

      if (!newDexRouterAddress) {
        throw new Error("Could not get newly deployed dexRouter address");
      }

      // Step 4: Update base.js with new implementation address
      console.log("\nStep 4: Updating implementation address...");
      const deployedDir = getDeployedDir(network);
      const baseBasePath = path.join(process.cwd(), 'scripts/deployed/' + deployedDir + '/base.js');
      let baseContent = fs.readFileSync(baseBasePath, 'utf8');

      baseContent = baseContent.replace(
        /newExactOutImpl:\s*["'].*["']/,
        `newExactOutImpl: "${newDexRouterAddress}"`
      );

      fs.writeFileSync(baseBasePath, baseContent);
      console.log(`Updated newImpl address to: ${newDexRouterAddress}`);

      if (network === 'zeta') {
        // step 5: verify contract for zeta
        console.log("\nStep 5: verifying contract for zeta")
        await hre.run("run", {
          script: "scripts/verify_zeta.js",
          network: network
        })
      } else {
        // Step 5: Verify contracts
        console.log("\nStep 5: Verifying contracts...");
        await hre.run("run", {
          script: "scripts/verify_etherscan_oklink.js",
          network: network
        });
      }




      // Step 6: Restore original files
      console.log("\nStep 6: Restoring original files...");
      await execPromise('git checkout -- contracts/8/libraries/CommonUtils.sol contracts/8/UnxswapV3Router.sol');

      console.log("\nDeployment and upgrade process completed successfully!");
    } catch (error) {
      console.error("Error during deployment:", error);

    }
  })

