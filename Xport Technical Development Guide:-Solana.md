Solana Xport Technical Development Guide: Cross-Chain Messaging Protocol

1. Protocol Overview and Development Environment

1.1. Introduction to Solana Xport

Solana Xport is a high-performance cross-chain messaging solution designed to facilitate secure communication between the Solana ecosystem and external blockchain networks. Development on Solana Xport is restricted to the Anchor framework. Developers must strictly adhere to the Solana Gateway standards established by Wanchain to ensure interoperability and protocol security.

1.2. Core Contract Infrastructure

The following core contracts facilitate messaging and configuration on the Solana Testnet:

Contract Name	Testnet Address
Gate-way	9J17hVJXCcMsD1E7Kv5yNKEgQAhwcu4NvtPQvXkgesiV
Admin-board	7jYCM8k5Nvwg5vyPpLk2yjivQhexPDMXuK8CSbUKqL6B

1.3. Development Rules

All custom applications (Apps) interacting with the protocol must implement standardized interfaces and pass mandatory security checks for cross-chain data. Failure to follow the Wanchain-defined Gateway rules will result in execution failure during the relay process.


--------------------------------------------------------------------------------


2. System Architecture and Component Definitions

2.1. Component Ecosystem

The ecosystem consists of seven primary components that coordinate message passing and execution:

Component Name	Category	Description
SolApp	Offline Application	An off-chain business application that invokes the on-chain App program.
App Program	On-Chain (Solana)	User-developed business logic on Solana following Gateway rules.
gate-way program	On-Chain (Solana)	Wanchain-developed program managing messaging rules and gateway operations.
agents	Middleware	Distributed agents that monitor and relay cross-chain events between networks.
WmbGateway contract	On-Chain (Target)	The gateway contract residing on the destination chain (e.g., EVM).
App contract	On-Chain (Target)	User-developed business logic on the destination chain.
OtherChainApp	Offline Application	An off-chain application interacting with the target chain's App contract.

2.2. Contract Relationship Hierarchy

1. Admin-board: The management layer; stores protocol-wide configurations and whitelists.
2. Gate-way: The core messaging engine; handles outbound_call and inbound_call operations.
3. App: The business logic layer; interacts with the Gate-way via Cross-Program Invocations (CPI).


--------------------------------------------------------------------------------


3. Outbound Messaging Workflow (Solana to Target Chain)

3.1. Process Lifecycle

1. Trigger: An off-chain application calls a method (e.g., cross_token_to_evm) on the Solana App program.
2. Initiation: The App program invokes the outbound_call method on the Gate-way program via CPI.
3. Event Emission: The Gate-way program validates the request and emits an InboundTaskExecuted event.
4. Relay: Distributed agents detect the event and submit the corresponding transaction to the destination chain.

3.2. Gateway Interface: outbound_call

Signature: pub fn outbound_call(ctx: Context<OutboundCall>, peer_chain_id: u128, peer_chain_app_address: Vec<u8>, func_call_data: Vec<u8>, source_contract_address: [u8;32], gas_limit: u64)

Parameter Name	Type	Description
peer_chain_id	u128	Unique identifier of the destination blockchain.
peer_chain_app_address	Vec<u8>	Address of the destination application contract.
func_call_data	Vec<u8>	Serialized message data for destination execution.
source_contract_address	[u8;32]	The Solana-based App program address.
gas_limit	u64	Maximum gas allocated for execution on the target chain.

3.3. Account Context (OutboundCall)

CRITICAL WARNING: The order of accounts in the OutboundCall CPI must exactly match the sequence below. Failure to maintain this order will cause the Gateway program to reject the instruction.

Account	Role	Purpose
nonce_account	UncheckedAccount	Stores and tracks the message nonce.
signer	Signer	The account authorizing the transaction and paying fees.
cpi_signer	Signer	A PDA (Seed: "CpiSigner") used to authorize the CPI call.
config_account	Account	A PDA (Seed: "ConfigData") for reading configuration from Admin-board.
system_program	Program	The standard Solana System Program.

3.4. Program Derived Address (PDA) Seeds

Chain IDs used in seeds must be represented as u128 16-byte little-endian arrays.

PDA Name	Program	Seeds
Cpi_signer	App Program	"CpiSigner"
ConfigData	Admin-board	"ConfigData"
Nonce	Gate-way	[solanaChainId (16B LE), otherChainId (16B LE), AppProgramId, OtherChainScAddr]


--------------------------------------------------------------------------------


4. Data Serialization and Formatting

4.1. Message Structure (MessageData)

The core data payload for business logic:

* message_type: String (e.g., "unlockToken")
* from: Vec<u8> (source address)
* to: Vec<u8> (destination address)
* amount: u64 (value to be transferred/processed)

4.2. Function Call Wrapper (FunctionCallData)

This struct wraps the core message for the Gateway:

* message_func: Vec<u8> (The byte representation of the string "wmbReceive")
* message_data: Vec<u8> (The serialized MessageData)

4.3. Inbound Container (InBoundFunctionCallData)

This struct is used when receiving messages from external chains:

* network_id: u128 (Source chain ID)
* contract_address: Vec<u8> (Source contract address)
* func_call_data: Vec<u8> (The serialized FunctionCallData)

4.4. Serialization Layers

func_call_data involves specific encoding standards:

1. Inner Layer (MessageData): Must be ABI-encoded for cross-chain compatibility with EVM-based targets.
2. Outer Layer (FunctionCallData): The wrapper is Borsh-serialized before being passed to outbound_call.
3. Inbound Reception: The incoming payload to wmb_receive is first decoded as a Borsh-serialized InBoundFunctionCallData.


--------------------------------------------------------------------------------


5. Inbound Messaging Workflow (Target Chain to Solana)

5.1. The Dual-Step Callback Process

Inbound execution requires a coordinated two-phase execution:

1. Account Resolution (wmb_receive_accounts): Off-chain agents call this to resolve dynamic dependencies. The AccountMetadata array returned here populates the Remaining Accounts for the next step.
2. Message Execution (wmb_receive): The Gateway calls this method to execute the business logic using the accounts resolved in Step 1.

5.2. Dynamic Account Resolution (wmb_receive_accounts)

* Context: Requires WmbReceiveAccountsContext, containing the auxiliary_pda (Seed: "Auxiliary").
* Response: Returns a WmbReceiveAccountsResponse containing the necessary accounts for the specific message type.

5.3. Message Execution (wmb_receive)

The execution context includes standard programs and the Gateway-authorized signer:

Account	Description
cpi_authority	Signer PDA (Seed: "CpiSigner") invoked by the Solana Gateway.
token_program	Standard SPL Token Program.
associated_token_program	Standard Associated Token Program.
system_program	Standard System Program.


--------------------------------------------------------------------------------


6. Implementation Reference (Code Samples)

6.1. On-Chain Rust Implementation (Outbound)

pub fn out_bound_call<'info>(ctx: Context<'_, '_, '_, 'info, CrossTokenToEvmAccounts<'info>>, peer_chain_id:u128, peer_app_address:Vec<u8>, function_call_data:Vec<u8>, gas_limit: u64) -> Result<()> {
    let curr_app_address = ctx.program_id.to_bytes();
    let params = OutBoundParams {
        network_id: peer_chain_id,
        contract_address: peer_app_address.clone(),
        function_call_data,
        source_contract_address: curr_app_address,
        gas_fee: gas_limit
    };

    let mut ix_data = Vec::new();
    ix_data.extend_from_slice(&constants::GATEWAY_OUTBOUND_CALL_IX_ID);
    ix_data.extend_from_slice(&params.try_to_vec().unwrap());

    // STRICT ACCOUNT ORDERING REQUIRED
    let accounts_meta = vec![
        AccountMeta::new(ctx.accounts.nonce_account.key(), false),
        AccountMeta::new(ctx.accounts.signer.key(), true),
        AccountMeta::new_readonly(ctx.accounts.cpi_signer.key(), true),
        AccountMeta::new_readonly(ctx.accounts.config_account.key(), false),
        AccountMeta::new_readonly(ctx.accounts.system_program.key(), false),
    ];

    let ix = Instruction::new_with_bytes(
        ctx.accounts.gateway_program.key(),
        &ix_data,
        accounts_meta,
    );

    let bump = ctx.bumps.cpi_signer;
    let signer_seeds: &[&[&[u8]]] = &[&[SEEDS::CPI_SIGNER.as_bytes(), &[bump]]];
    invoke_signed(&ix, &ctx.accounts.to_account_infos(), signer_seeds)?;
    Ok(())
}


6.2. Client-Side JavaScript Implementation (Nonce PDA)

// Correct derivation of Nonce PDA using 16-byte little-endian chain IDs
const solanaChainIdBytes = new ArrayBuffer(16);
const solanaChainIdView = new DataView(solanaChainIdBytes);
solanaChainIdView.setBigUint64(0, BigInt(SOLANA_CHAIN_ID), true); // little-endian

const peerChainIdBytes = new ArrayBuffer(16);
const peerChainIdView = new DataView(peerChainIdBytes);
peerChainIdView.setBigUint64(0, BigInt(peer_chain_id), true); // little-endian

const [nonceAccount] = await PublicKey.findProgramAddress(
    [
        Buffer.from(new Uint8Array(solanaChainIdBytes)),
        Buffer.from(new Uint8Array(peerChainIdBytes)),
        Buffer.from(source_contract_address),
        Buffer.from(peer_app_address)
    ],
    gateway_programPublicKey
);


6.3. Inbound Dynamic Resolution (Rust)

pub fn wmb_receive_accounts(ctx: Context<WmbReceiveAccountsContext>, data: Vec<u8>) -> Result<WmbReceiveAccountsResponse> {
    // Note: ctx contains auxiliary_pda with seed "Auxiliary"
    match decode_message_data(&data) {
        Ok(message_data) => {
            let mut accounts = Vec::new();
            if message_data.message_type == "unlockToken" {
                accounts.push(AccountMetadata { pubkey: TOKEN_PROGRAM_ID, is_writable: false, is_signer: false });
                accounts.push(AccountMetadata { pubkey: ASSOCIATED_TOKEN_PROGRAM_ID, is_writable: false, is_signer: false });
                accounts.push(AccountMetadata { pubkey: SYSTEM_PROGRAM_ID, is_writable: false, is_signer: false });
            }
            Ok(WmbReceiveAccountsResponse { accounts })
        },
        Err(e) => Err(e),
    }
}



--------------------------------------------------------------------------------


7. Security and Verification Standards

7.1. CPI Validation

It is mandatory to verify that the cpi_authority in the wmb_receive call belongs to the official Gateway. Implement a check against the Gate-way Program ID: 9J17hVJXCcMsD1E7Kv5yNKEgQAhwcu4NvtPQvXkgesiV.

7.2. Whitelist Verification

During the execution of wmb_receive, the App must:

1. Borsh-deserialize the payload into InBoundFunctionCallData.
2. Validate that the network_id and contract_address exist within the App’s internal whitelist of authorized peer contracts.
3. Only after source verification should the inner func_call_data (containing the ABI-encoded MessageData) be processed.
