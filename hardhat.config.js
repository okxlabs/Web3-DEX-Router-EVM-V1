require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-solhint");
require('hardhat-abi-exporter');
require("hardhat-gas-reporter");
require("solidity-coverage");
require('hardhat-contract-sizer');
require('hardhat-log-remover');
require("@openzeppelin/hardhat-upgrades");
require('dotenv').config();
require("./scripts/multichain.js");
require("./tasks/deploy-and-verify");
require("./tasks/check-impl");

// Deployer/signer key. On local networks (hardhat/localhost, or no --network) we fall back
// to the well-known Hardhat test account so compile/test work without a key. On any real
// network we FAIL FAST when PRIVATE_KEY is missing, rather than silently signing with the
// public test key (which would otherwise happen and is dangerous on a live chain).
const HARDHAT_TEST_KEY = 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const LOCAL_NETWORKS = new Set(['hardhat', 'localhost']);
const TARGET_NETWORK =
  process.env.HARDHAT_NETWORK ||
  (process.argv.includes('--network') ? process.argv[process.argv.indexOf('--network') + 1] : undefined);
const PRIVATE_KEY = (() => {
  if (process.env.PRIVATE_KEY) return process.env.PRIVATE_KEY;
  if (!TARGET_NETWORK || LOCAL_NETWORKS.has(TARGET_NETWORK)) return HARDHAT_TEST_KEY;
  throw new Error(
    `PRIVATE_KEY is not set, but the target network "${TARGET_NETWORK}" is not local. ` +
      `Refusing to fall back to the public Hardhat test key on a live network. ` +
      `Set PRIVATE_KEY in your .env before running against "${TARGET_NETWORK}".`
  );
})();
const ALCHEMY_KEY = process.env.ALCHEMY_KEY || '';
const INFSTONES_KEY = process.env.INFSTONES_KEY || '';
const INFURA_KEY = process.env.INFURA_KEY || '';
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || '';
const ARBITRUMSCAN_API_KEY = process.env.ARBITRUMSCAN_API_KEY || '';
const OPSCAN_API_KEY = process.env.OPSCAN_API_KEY || '';
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || '';
const BASESCAN_API_KEY = process.env.BASESCAN_API_KEY || '';
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || '';
const OKLINK_API_KEY = process.env.OKLINK_API_KEY || '';
const LINEASCAN_API_KEY = process.env.LINEASCAN_API_KEY || '';
const MANTLESCAN_API_KEY = process.env.MANTLESCAN_API_KEY || '';
const XLAYERSCAN_API_KEY = process.env.XLAYERSCAN_API_KEY || '';
const MODESCAN_API_KEY = process.env.MODESCAN_API_KEY || '';
const MANTASCAN_API_KEY = process.env.MANTASCAN_API_KEY || '';
const SCROLLSCAN_API_KEY = process.env.SCROLLSCAN_API_KEY || '';
const AVAXSCAN_API_KEY = process.env.AVAXSCAN_API_KEY || '';
const BLASTSCAN_API_KEY = process.env.BLASTSCAN_API_KEY || '';
const SONIC_API_KEY = process.env.SONIC_API_KEY || '';
const ZETA_API_KEY = process.env.ZETA_API_KEY || '123';
const ZKSYNC_ETH_NETWORK = process.env.ZKSYNC_ETH_NETWORK || 'mainnet';
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: '^0.8.0',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  zksolc: {
    version: "1.3.1",
    compilerSource: "binary",
    settings: {},
  },
  networks: {
    hardhat: {
      chainId: 31337,
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000,
      // forking:
      // {
      //   url: "https://rpc.ankr.com/eth"
      // }
    },
    robinhood: {
      url: process.env.ROBINHOOD_RPC_URL || 'https://rpc.mainnet.chain.robinhood.com',
      chainId: 4663,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    monad: {
      url: process.env.MONAD_RPC_URL || '',
      chainId: 143,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    pharos: {
      url: process.env.PHAROS_RPC_URL || 'https://rpc.pharos.xyz',
      chainId: 1672,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    okc: {
      url: process.env.OKC_RPC_URL || (INFSTONES_KEY == '' ? "https://exchainrpc.okex.org" : `https://api.infstones.com/okc-archive/mainnet/${INFSTONES_KEY}`),
      chainId: 66,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    tron: {
      url: process.env.TRON_RPC_URL || "https://api.trongrid.io",
      chainId: 65,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    tron: {
      url: process.env.TRON_TEST_RPC_URL || "https://exchaintestrpc.okex.org",
      chainId: 65,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    zeta: {
      url: process.env.ZETA_RPC_URL || 'https://zeta-chain.drpc.org',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    flare: {
      url: process.env.FLARE_RPC_URL || "https://flare-api.flare.network/ext/C/rpc",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    bsc: {
      url: process.env.BSC_RPC_URL || "https://bsc-dataseed1.defibit.io",
      chainId: 56,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    bsc_dev: {
      url: process.env.BSC_DEV_RPC_URL || "https://rpc.ankr.com/bsc",
      chainId: 56,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    bsc_test: {
      url: process.env.BSC_TEST_RPC_URL || "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    eth: {
      url: process.env.ETH_RPC_URL || (ALCHEMY_KEY == '' ? "https://eth.llamarpc.com" : `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`),
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    goerli: {
      url: process.env.GOERLI_RPC_URL || `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || `https://rpc.sepolia.org`,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    cro: {
      url: process.env.CRO_RPC_URL || "https://cronos-evm-rpc.publicnode.com",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    crotest: {
      url: process.env.CROTEST_RPC_URL || "https://cronos-testnet-3.crypto.org:8545",
      accounts: [`${PRIVATE_KEY}`],
      network_id: "*",
      skipDryRun: true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    avax: {
      url: process.env.AVAX_RPC_URL || "https://1rpc.io/avax/c",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    avaxtest: {
      url: process.env.AVAXTEST_RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: [`${PRIVATE_KEY}`],
      gas: 2100000,
      gasPrice: 25000000000,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon.lava.build",
      accounts: [`${PRIVATE_KEY}`],
      gasPrice: 250000000000,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    polygontest: {
      url: process.env.POLYGONTEST_RPC_URL || "https://rpc-mumbai.maticvigil.com/",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    arb: {
      url: process.env.ARB_RPC_URL || "https://arb1.arbitrum.io/rpc",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    op: {
      url: process.env.OP_RPC_URL || "https://optimism-rpc.publicnode.com",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    ftm: {
      url: process.env.FTM_RPC_URL || "https://1rpc.io/ftm",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    ethw: {
      url: process.env.ETHW_RPC_URL || "https://mainnet.ethereumpow.org",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    conflux: {
      url: process.env.CONFLUX_RPC_URL || "https://evm.confluxrpc.com",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    polyzkevm: {
      url: process.env.POLYZKEVM_RPC_URL || "https://zkevm-rpc.com",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    zksync: {
      url: process.env.ZKSYNC_RPC_URL || "https://mainnet.era.zksync.io",
      ethNetwork: ZKSYNC_ETH_NETWORK,
      zksync: true,
      chainId: 324,
      verifyURL: "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    linea: {
      url: process.env.LINEA_RPC_URL || `https://1rpc.io/linea`,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    mantle: {
      url: process.env.MANTLE_RPC_URL || `https://rpc.mantle.xyz`,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    base: {
      url: process.env.BASE_RPC_URL || 'https://base-mainnet.public.blastapi.io',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    scroll: {
      url: process.env.SCROLL_RPC_URL || "https://rpc.scroll.io",
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    basetest: {
      url: process.env.BASETEST_RPC_URL || 'https://goerli.base.org',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    canto: {
      url: process.env.CANTO_RPC_URL || 'https://mainnode.plexnode.org:8545',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    manta: {
      url: process.env.MANTA_RPC_URL || 'https://pacific-rpc.manta.network/http',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    metis: {
      url: process.env.METIS_RPC_URL || 'https://andromeda.metis.io/?owner=1088',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    merlin: {
      url: process.env.MERLIN_RPC_URL || 'https://rpc.merlinchain.io',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    xlayer: {
      url: process.env.XLAYER_RPC_URL || 'https://rpc.xlayer.tech',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    xlayer_test: {
      url: 'https://testrpc.xlayer.tech',
      chainId: 1952,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    blast: {
      url: process.env.BLAST_RPC_URL || 'https://rpc.blast.io',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    mode: {
      url: process.env.MODE_RPC_URL || 'https://mainnet.mode.network',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    sei: {
      url: process.env.SEI_RPC_URL || 'https://evm-rpc.sei-apis.com',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    moonbeam: {
      url: process.env.MOONBEAM_RPC_URL || 'https://rpc.ankr.com/moonbeam',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    iotex: {
      url: process.env.IOTEX_RPC_URL || 'https://babel-api.mainnet.iotex.one',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    apechain: {
      url: process.env.APECHAIN_RPC_URL || 'https://rpc.apechain.com/http',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    taiko: {
      url: process.env.TAIKO_RPC_URL || 'https://rpc.mainnet.taiko.xyz',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    story: {
      url: process.env.STORY_RPC_URL || 'https://homer.storyrpc.io',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    sonic: {
      url: process.env.SONIC_RPC_URL || 'https://sonic-rpc.publicnode.com',
      chainId: 146,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    berachain: {
      url: process.env.BERACHAIN_RPC_URL || 'https://rpc.berachain-apis.com',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    unichain: {
      url: process.env.UNICHAIN_RPC_URL || 'https://unichain.drpc.org',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    plasma: {
      url: process.env.PLASMA_RPC_URL || 'https://rpc.plasma.to',
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    hyperevm: {
      url: process.env.HYPEREVM_RPC_URL || 'https://rpc.hyperliquid.xyz/evm',
      chainId: 999,
      accounts: [`${PRIVATE_KEY}`],
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
  },
  paths: {
    sources: './contracts/8',
    cache: './cache',
    artifacts: './artifacts'
  },
  abiExporter: {
    path: './abi',
    clear: true,
    flat: false,
    runOnCompile: true,
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: false,
    strict: true,
  },
  gasReporter: {
    enabled: true
  },
  mocha: {
    timeout: 180000000
  },
  okxweb3explorer: {
    apiKey: OKLINK_API_KEY ?? "",
  },
  etherscan: {
    apiKey: {
      mainnet: ETHERSCAN_API_KEY,
      arbitrumOne: ETHERSCAN_API_KEY,
      optimisticEthereum: ETHERSCAN_API_KEY,
      bsc: ETHERSCAN_API_KEY,
      base: ETHERSCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      linea: ETHERSCAN_API_KEY,
      mantle: ETHERSCAN_API_KEY,
      xlayer: XLAYERSCAN_API_KEY,
      xlayer_test: XLAYERSCAN_API_KEY,
      mode: MODESCAN_API_KEY,
      manta: MANTASCAN_API_KEY,
      scroll: ETHERSCAN_API_KEY,
      avalanche: ETHERSCAN_API_KEY,
      avax: AVAXSCAN_API_KEY,
      blast: ETHERSCAN_API_KEY,
      blast_ok: ETHERSCAN_API_KEY,
      story: 'empty',
      sonic: ETHERSCAN_API_KEY,
      zeta: ZETA_API_KEY,
      zksync: ETHERSCAN_API_KEY,
      unichain: ETHERSCAN_API_KEY,
      sei: ETHERSCAN_API_KEY,
      apechain: ETHERSCAN_API_KEY,
      robinhood: 'empty', // Blockscout instance, no API key required
    },
    customChains: [
      {
        // Robinhood Chain is NOT on the Etherscan v2 multichain API; its Blockscout
        // instance exposes an Etherscan-compatible API at /api
        network: "robinhood",
        chainId: 4663,
        urls: {
          apiURL: "https://robinhoodchain.blockscout.com/api",
          browserURL: "https://robinhoodchain.blockscout.com"
        }
      },
      {
        network: "mainnet",
        chainId: 1,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=1",
          browserURL: "https://etherscan.io"
        }
      },
      {
        network: "optimisticEthereum",
        chainId: 10,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=10",
          browserURL: "https://optimistic.etherscan.io"
        }
      },
      {
        network: "bsc",
        chainId: 56,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=56",
          browserURL: "https://bscscan.com"
        }
      },
      {
        network: "unichain",
        chainId: 130,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=130",
          browserURL: "https://unichain.blockscout.com/"
        }
      },
      {
        network: "zksync",
        chainId: 324,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=324",
          browserURL: "https://zkscan.io"
        }
      },
      {
        network: "sei",
        chainId: 1329,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=1329",
          browserURL: "seiscan.io"
        }
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=8453",
          browserURL: "https://basescan.org"
        }
      },
      {
        network: "apechain",
        chainId: 33111,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=33111",
          browserURL: "https://apescan.io"
        }
      },
      {
        network: "arbitrumOne",
        chainId: 42161,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=42161",
          browserURL: "https://arbiscan.io"
        }
      },
      {
        network: "avalanche",
        chainId: 43114,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=43114",
          browserURL: "https://avascan.info"
        }
      },
      {
        network: "linea",
        chainId: 59144,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=59144",
          browserURL: "https://lineascan.build"
        }
      },
      {
        network: "mantle",
        chainId: 5000,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=5000",
          browserURL: "https://mantlescan.xyz"
        }
      },
      {
        network: "zeta",
        chainId: 7000,
        urls: {
          apiURL: "https://explorer.zetachain.com.",
          browserURL: "https://zetachain.blockscout.com"
        }
      },
      {
        network: "manta",
        chainId: 5000,
        urls: {
          apiURL: "https://api.w3w.ai/manta-pacific/v1/explorer/command_api/contract",
          browserURL: "https://manta.socialscan.io/"
        }
      },
      {
        network: "mode",
        chainId: 34443,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/34443/etherscan",
          browserURL: "https://modescan.io"
        }
      },
      {
        network: "scroll",
        chainId: 534352,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=534352",
          browserURL: "https://scrollscan.com"
        }
      },
      {
        network: "blast",
        chainId: 81457,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=81457",
          browserURL: "https://blastscan.com"
        }
      },
      {
        network: "story",
        chainId: 1514,
        urls: {
          apiURL: "https://www.storyscan.xyz/api",
          browserURL: "https://www.storyscan.xyz"
        }
      },
      {
        network: "polygon",
        chainId: 137,
        urls: {
          apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/POLYGON", 
          browserURL: "https://www.oklink.com"
        }
      },
      {
        network: "linea",
        chainId: 59144,
        urls: { 
          apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/LINEA", 
          browserURL: "https://www.oklink.com"
        }
      },
      {
        network: "manta",
        chainId: 169,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/MANTA", browserURL: "https://www.oklink.com", }
      },
      {
        network: "xlayer",
        chainId: 196,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/XLAYER", browserURL: "https://www.oklink.com", }
      },
      {
        network: "xlayer_test",
        chainId: 1952,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/XLAYER_TESTNET", browserURL: "https://www.oklink.com", }
      },
      {
        network: "scroll",
        chainId: 534352,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/SCROLL", browserURL: "https://www.oklink.com", }
      },
      {
        network: "avax",
        chainId: 43114,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/AVAXC", browserURL: "https://www.oklink.com", }
      },
      {
        network: "blast_ok",
        chainId: 81457,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/BLAST", browserURL: "https://www.oklink.com", }
      },
      {
        network: "story",
        chainId: 1514,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/STORY", browserURL: "https://www.oklink.com", }
      },
      {
        network: "sonic",
        chainId: 146,
        urls: { apiURL: "https://api.etherscan.io/v2/api?chainid=146", browserURL: "https://sonicscan.org", }
      }
    ]
  },

}
