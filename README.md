## Carbon Trading

### 解決問題

目前碳權交易大多需要透過中間人媒合，以至於交易時間較長、價格較不透明，透過鏈上交易可以更直接達成交易、交換、抵銷等功能

### Testing

```
forge test --mp test/FactoryTest.t.sol
forge script --rpc-url https://rpc.ankr.com/eth_sepolia script/Setup.s.sol:SetupScript --broadcast
```

Create `.env`

```
PRIVATE_KEY=
ADMIN=
MAINNET_RPC_URL=
```

### 使用流程

#### 提供減碳的角色 ex: 森林地主：

1. 森林地主到 Carbon Trading Platform 去註冊 Project
2. 森林地主 Carbon Trading Platform 去 Claim 可提供減碳的量（Reduction
3. Admin 加入合格的 Auditor
4. 經過 Auditor 審核通過後森林地主會拿到
5. 一張 Green NFT 紀錄土地資訊、核發減碳的量
6. 核發減碳的量的 Project Token
7. 森林地主拿到 Project Token 後 Pool 存入 Project Token 1:1 換取 Pool Toke
8. 森林地主拿到 Pool Token 後，可以到
   - Swapper 提供流動性轉取手續費
   - Pool 透過 redeem 方式達到交換 Project Token 的目的

#### 購買減碳量的角色 ex: 工廠

1. 工廠管理者先到 Carbon Trading Platform 去註冊 Project
2. 工廠管理者到 Carbon Trading Platform 去 Claim 碳排量（Emission）
3. 先到 Swapper 用 USDC swap Pool Token
4. 工廠管理者拿到 Pool Token 後需要到 Pool 去 redeem 回 Project Token 才能做抵銷 Offset
5. Redeem 方式有三種：
   - 10% 手續費：指定要 redeem 回哪個 Project Token
   - 8% 手續費：從 Pool 中有的 Project Token 隨機挑出一個
   - 5%：從 Pool 中最舊的 Project Token
6. 工廠管理者拿到 Project Token 後，就可以進行 Offset
   - 會把 Project Token burn 掉
   - 工廠管理者拿到 Offset Certificate 紀錄這次 Offset 是從那個 Project offset 和 offset 數量

#### 解決 ERC20 無法紀錄來源的方式

每個 Project 都會有自己的 ERC20 Token，透過 Project Token 直接交易可以知道這個 token 來自哪個 Project，但會造成流動性低等問題，因此在中間交易過程透 Project Pool Token 1:1 deposit 方式，可以讓不同 Project 之間達到交換、交易更容易，redeem 再決定要 redeem 哪種 Project Token，Offset 再決定用哪種 Project Token 去 Offset。

### Contract

#### 合約中的 Token

1. Project Token
2. Pool Token
3. GreenNFT
4. OffsetCertificate

#### 合約的功能

1. Factory : register, claim, audit project
2. Pool : deposit, redeem, offset project token, random number from chainlink
3. Swapper : add liquidity, swap Pool Token

#### 合約架構圖

![](https://hackmd.io/_uploads/SkNXtmud6.png)

#### User Flow

![](https://hackmd.io/_uploads/H1wtO7Oua.png)
