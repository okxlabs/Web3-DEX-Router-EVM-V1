require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-solhint");
require('hardhat-abi-exporter');
require("hardhat-gas-reporter");
require("solidity-coverage");
require('hardhat-contract-sizer');
require('hardhat-log-remover');
require("@openzeppelin/hardhat-upgrades");
require('dotenv').config();
require('@okxweb3/hardhat-explorer-verify');

require("@zetachain/toolkit/tasks");

// Note: If no private key is configured in the project, the first test account of Hardhat is used by default
const DEPLOYER_KEY = process.env.PRIVATE_KEY_DEPLOYER || process.env.PRIVATE_KEY;
const DEPLOYER_ACCOUNTS = DEPLOYER_KEY ? [DEPLOYER_KEY] : [];
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
const ZETA_API_KEY = process.env.ZETA_API_KEY || '';
// Public network entries are enabled when their RPC URL is supplied.
// This avoids embedding private RPC endpoints or placeholder URLs in the public repository.
const OPTIONAL_NETWORKS = [
  ['unichain', 130, 'UNICHAIN_RPC_URL'],
  ['monad', 143, 'MONAD_RPC_URL'],
  ['plasma', 9745, 'PLASMA_RPC_URL'],
  ['pharos', 1672, 'PHAROS_RPC_URL'],
  ['hyperevm', 999, 'HYPEREVM_RPC_URL'],
  ['robinhood', 4663, 'ROBINHOOD_RPC_URL'],
  ['ink', 57073, 'INK_RPC_URL'],
  ['arc', 5042, 'ARC_RPC_URL'],
  ['elysium', 99901, 'ELYSIUM_RPC_URL'],
].reduce((networks, [name, chainId, envName]) => {
  const url = process.env[envName];
  if (url) networks[name] = { url, chainId, accounts: DEPLOYER_ACCOUNTS };
  return networks;
}, {});
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        }
      },
    ]
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
    ...OPTIONAL_NETWORKS,
    okc: {
      url: INFSTONES_KEY == '' ? "https://exchainrpc.okex.org" : `https://api.infstones.com/okc-archive/mainnet/${INFSTONES_KEY}`,
      chainId: 66,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    tron: {
      url: "https://api.trongrid.io",
      chainId: 65,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    okc_test: {
      url: "https://exchaintestrpc.okex.org",
      chainId: 65,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    zeta: {
      url: 'https://zetachain-mainnet.public.blastapi.io',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    flare: {
      url: "https://flare-api.flare.network/ext/C/rpc",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    bsc: {
      url: "https://bsc-dataseed1.defibit.io",
      chainId: 56,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    bsc_stg: {
      url: "https://bsc.blockrazor.xyz",
      chainId: 56,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    bsc_dev: {
      url: "https://rpc.ankr.com/bsc",
      chainId: 56,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    bsc_test: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    eth: {
      url: ALCHEMY_KEY == '' ? "https://eth.llamarpc.com" : `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    eth_stg: {
      url: ALCHEMY_KEY == '' ? "https://eth.llamarpc.com" : `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    sepolia: {
      url: `https://rpc.sepolia.org`,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    cro: {
      url: "https://cronos.drpc.org",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    crotest: {
      url: "https://cronos-testnet-3.crypto.org:8545",
      accounts: DEPLOYER_ACCOUNTS,
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
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    avaxtest: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: DEPLOYER_ACCOUNTS,
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
      url: "https://rpc-mainnet.matic.quiknode.pro",
      accounts: DEPLOYER_ACCOUNTS,
      gasPrice: 250000000000,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    polygontest: {
      url: "https://rpc-mumbai.maticvigil.com/",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    arb: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    arb_stg: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    op: {
      url: "https://optimism-mainnet.public.blastapi.io",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    ftm: {
      url: "https://fantom-json-rpc.stakely.io",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    ethw: {
      url: "https://mainnet.ethereumpow.org",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
    conflux: {
      url: "https://evm.confluxrpc.com",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    polyzkevm: {
      url: "https://zkevm-rpc.com",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    zksync: {
      url: "https://mainnet.era.zksync.io",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    linea: {
      url: `https://1rpc.io/linea`,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    mantle: {
      url: `https://rpc.mantle.xyz`,
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    base: {
      url: 'https://base-mainnet.public.blastapi.io',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    base_stg: {
      url: 'https://mainnet.base.org',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    scroll: {
      url: "https://rpc.scroll.io" || "",
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    basetest: {
      url: 'https://goerli.base.org',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    canto: {
      url: 'https://mainnode.plexnode.org:8545',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    manta: {
      url: 'https://pacific-rpc.manta.network/http',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    metis: {
      url: 'https://andromeda.metis.io/?owner=1088',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    merlin: {
      url: 'https://endpoints.omniatech.io/v1/merlin/mainnet/public',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    xlayer: {
      url: 'https://rpc.xlayer.tech',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    blast: {
      url: 'https://rpc.blast.io',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    mode: {
      url: 'https://mainnet.mode.network',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    sei: {
      url: 'https://evm-rpc.sei-apis.com',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    moonbeam: {
      url: 'https://rpc.ankr.com/moonbeam',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    iotex: {
      url: 'https://babel-api.fastblocks.io',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    apechain: {
      url: 'https://rpc.apechain.com/http',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    taiko: {
      url: 'https://rpc.mainnet.taiko.xyz',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    story: {
      url: 'https://homer.storyrpc.io',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    sonic: {
      url: 'https://sonic.drpc.org',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
    berachain: {
      url: 'https://rpc.berachain-apis.com',
      accounts: DEPLOYER_ACCOUNTS,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    }
  },
  paths: {
    sources: './contracts/8'
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
      arbitrumOne: ARBITRUMSCAN_API_KEY,
      optimisticEthereum: OPSCAN_API_KEY,
      bsc: BSCSCAN_API_KEY,
      base: BASESCAN_API_KEY,
      polygon: POLYGONSCAN_API_KEY,
      linea: LINEASCAN_API_KEY,
      mantle: MANTLESCAN_API_KEY,
      xlayer: XLAYERSCAN_API_KEY,
      mode: MODESCAN_API_KEY,
      manta: MANTASCAN_API_KEY,
      scroll: SCROLLSCAN_API_KEY,
      avalanche: AVAXSCAN_API_KEY,
      avax: AVAXSCAN_API_KEY,
      blast: BLASTSCAN_API_KEY,
      blast_ok: BLASTSCAN_API_KEY,
      story: 'empty',
      sonic: SONIC_API_KEY,
      zeta: ZETA_API_KEY
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      },
      {
        network: "linea",
        chainId: 59144,
        urls: {
          apiURL: "https://api.lineascan.build/api",
          browserURL: "https://lineascan.build"
        }
      },
      {
        network: "mantle",
        chainId: 5000,
        urls: {
          apiURL: "https://api.mantlescan.xyz/api",
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
          apiURL: "https://api.scrollscan.com/api",
          browserURL: "https://scrollscan.com"
        }
      },
      {
        network: "blast",
        chainId: 81457,
        urls: {
          apiURL: "https://api.blastscan.io/api",
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
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/POLYGON", browserURL: "https://www.oklink.com", }
      },
      {
        network: "linea",
        chainId: 59144,
        urls: { apiURL: "https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/LINEA", browserURL: "https://www.oklink.com", }
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
        urls: { apiURL: "https://api.sonicscan.org/api", browserURL: "https://sonicscan.org", }
      }
    ]
  },

}
