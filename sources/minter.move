module myself::minter {
    use std::option;
    use std::signer;
    use std::string;
    use aptos_std::string_utils;
    use aptos_framework::account;
    use aptos_framework::object;
    use aptos_token_objects::collection;
    use aptos_token_objects::royalty;
    use aptos_token_objects::token;

    use myself::object_refs;

    const MAX_SUPPLY: u64 = 250;

    struct MinterConfig has key {
        collection_addr: address,
        signer_cap: account::SignerCapability,
    }

    /// The caller is not authorized to perform this action
    const ENOT_AUTHORIZED: u64 = 1;
    /// The caller has already minted an NFT
    const EUSER_ALREADY_MINTED: u64 = 2;
    /// All of the NFTs have already been minted
    const EALL_TOKENS_ALREADY_MINTED: u64 = 3;

    const COLLECTION_NAME: vector<u8> = b"Aptos IIT 2023 Event Selfie";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Max took a selfie at the Aptos IIT 2023 Event in Mumbai, and now everyone is on the blockchain forever! Limited edition of 250.";
    const TOKEN_NAME: vector<u8> = b"Aptos IIT 2023 Event Selfie with Max";
    const TOKEN_DESCRIPTION: vector<u8> = b"Limited edition 250 Aptos IIT 2023 Event selfies with Max";

    // TODO: PUT REAL URL HERE
    const TOKEN_IMAGE_URL: vector<u8> = b"https://gateway.pinata.cloud/ipfs/QmQADe2h43nZTZaRaJYknFgFwsugiRSHjS8NCYHymFd1os";

    /// Creates a single collection for the entire contract
    /// This is open to discussion
    fun init_module(
        deployer: &signer,
    ) {
        let deployer_addr = signer::address_of(deployer);
        assert!(deployer_addr == @myself, ENOT_AUTHORIZED);

        let (resource_signer, signer_cap) = account::create_resource_account(deployer, b"Aptos IIT 2023");

        let constructor_ref = collection::create_fixed_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            MAX_SUPPLY,
            string::utf8(COLLECTION_NAME),
            option::none<royalty::Royalty>(),
            string::utf8(b"https://aptoslabs.com/"),
        );
        object_refs::create_refs(&constructor_ref);

        move_to(deployer, MinterConfig {
            signer_cap,
            collection_addr: object::address_from_constructor_ref(&constructor_ref),
        });
    }

    fun get_resource_signer(): signer acquires MinterConfig {
        account::create_signer_with_capability(&borrow_global<MinterConfig>(@myself).signer_cap)
    }

    fun get_collection_count(): u64 acquires MinterConfig {
        let minter_config = borrow_global<MinterConfig>(@myself);
        let collection_object = object::address_to_object<object::ObjectCore>(minter_config.collection_addr);
        option::extract(&mut collection::count(collection_object))
    }

    public entry fun claim_mint(user: &signer) acquires MinterConfig {
        claim_mint_inner(user);
    }

    fun claim_mint_inner(user: &signer): (address) acquires MinterConfig {
        // Mints 1 NFT to the signer
        let resource_signer = get_resource_signer();

        let count = get_collection_count();
        assert!(count < MAX_SUPPLY, EALL_TOKENS_ALREADY_MINTED);

        // Set up the NFT
        // Mint it with the user as the name- ensures user can only mint one
        let user_address = signer::address_of(user);

        let collection_name = string::utf8(COLLECTION_NAME);
        let address_name = string_utils::to_string_with_canonical_addresses(&user_address);
        let token_address = token::create_token_address(
            &signer::address_of(&resource_signer),
            &collection_name,
            &address_name,
        );
        assert!(!object::object_exists<object::ObjectCore>(token_address), EUSER_ALREADY_MINTED);

        let token_constructor_ref = token::create_named_token(
            &resource_signer,
            collection_name,
            string::utf8(TOKEN_DESCRIPTION),
            address_name,
            option::none<royalty::Royalty>(),
            string::utf8(TOKEN_IMAGE_URL),
        );

        // Rename the token to the actual token name
        let token_name = string::utf8(TOKEN_NAME);
        string::append_utf8(&mut token_name, b": #");
        let count_str = string_utils::to_string(&(count + 1));
        string::append(&mut token_name, count_str);

        let token_mutator_ref = token::generate_mutator_ref(&token_constructor_ref);
        token::set_name(&token_mutator_ref, token_name);

        // Finally, transfer ownership to the user
        let token_address = object::address_from_constructor_ref(&token_constructor_ref);
        object::transfer_raw(&resource_signer, token_address, user_address);

        (token_address)
    }

    #[test_only]
    public fun setup_and_mint(aptos: &signer, user: &signer, myself: &signer) {
        aptos_framework::timestamp::set_time_has_started_for_testing(aptos);
        account::create_account_for_test(signer::address_of(user));
        account::create_account_for_test(signer::address_of(myself));
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos);
        aptos_framework::coin::destroy_burn_cap(burn_cap);
        aptos_framework::coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos = @0x1, user = @0x123ff, myself = @myself)]
    #[expected_failure(abort_code = EUSER_ALREADY_MINTED, location = Self)]
    public entry fun test_user_already_minted(
        aptos: signer,
        user: signer,
        myself: signer
    ) acquires MinterConfig {
        setup_and_mint(&aptos, &user, &myself);
        init_module(&myself);

        claim_mint(&user);
        claim_mint(&user);
    }

    #[test(aptos = @0x1, user = @0x123ff, myself = @myself)]
    #[expected_failure(abort_code = EALL_TOKENS_ALREADY_MINTED, location = Self)]
    public entry fun test_mint_limit(
        aptos: signer,
        user: signer,
        myself: signer
    ) acquires MinterConfig {
        setup_and_mint(&aptos, &user, &myself);
        init_module(&myself);

        let i = 0;
        while (i <= 251) {
            let address = object::create_guid_object_address(@0x1111, i);
            let user_signer = account::create_account_for_test(address);
            claim_mint(&user_signer);
            i = i + 1;
        };
        abort 100
    }

    #[test(aptos = @0x1, user1 = @0x111, user2 = @0x222, myself = @myself)]
    public entry fun test_e2e(
        aptos: signer,
        user1: signer,
        user2: signer,
        myself: signer
    ) acquires MinterConfig {
        setup_and_mint(&aptos, &user1, &myself);
        account::create_account_for_test(signer::address_of(&user2));
        init_module(&myself);

        let token1_address = claim_mint_inner(&user1);
        let token1_object = object::address_to_object<object::ObjectCore>(token1_address);
        assert!(object::is_owner(token1_object, signer::address_of(&user1)), 10);
        let name1 = token::name(token1_object);
        let name1_len = string::length(&name1);
        assert!(string::sub_string(&name1, name1_len - 4, name1_len) == string::utf8(b": #1"), 11);

        let token2_address = claim_mint_inner(&user2);
        let token2_object = object::address_to_object<object::ObjectCore>(token2_address);
        assert!(object::is_owner(token2_object, signer::address_of(&user2)), 20);
        let name2 = token::name(token2_object);
        let name2_len = string::length(&name2);
        assert!(string::sub_string(&name2, name2_len - 4, name2_len) == string::utf8(b": #2"), 21);
    }
}