module myself::xangle {
    use aptos_framework::account;
    use aptos_std::table;
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_token::token;
    use std::bcs;

    const MAX_SUPPLY: u64 = 250;

    struct Minter has store, key {
        counter: u64,
        mints: table::Table<address, bool>,
        signer_cap: account::SignerCapability,
    }

    const ENOT_AUTHORIZED: u64 = 1;
    const EHAS_ALREADY_CLAIMED_MINT: u64 = 2;
    const EMINTING_NOT_ENABLED: u64 = 3;

    const COLLECTION_NAME: vector<u8> = b"Xangle Selfie";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Max took a selfie at the Aptos<>Xangle event in Seoul, and now everyone is on the blockchain forever! Limited edition of 250.";
    const TOKEN_NAME: vector<u8> = b"Xangle Selfie with Max";
    const TOKEN_DESCRIPTION: vector<u8> = b"Limited edition 250 Aptos<>Xangle selfies with Max";

    // TODO: BOWEN TO PUT REAL URL HERE
    const TOKEN_IMAGE_URL: vector<u8> = b"https://aptoslabs.com/nft_images/aptos-zero/???";

    fun init_module(sender: &signer) {
        // Create the resource account, so we can get ourselves as signer later
        let (resource, signer_cap) = account::create_resource_account(sender, vector::empty());

        // Set up NFT collection
        let collection_name = string::utf8(COLLECTION_NAME);
        let description = string::utf8(COLLECTION_DESCRIPTION);
        let collection_uri = string::utf8(b"https://aptoslabs.com/");
        let maximum_supply = MAX_SUPPLY;
        let mutate_setting = vector<bool>[ false, false, false ];
        token::create_collection(
            &resource,
            collection_name,
            description,
            collection_uri,
            maximum_supply,
            mutate_setting
        );

        move_to(sender, Minter { counter: 1, mints: table::new(), signer_cap });
    }

    fun get_resource_signer(): signer acquires Minter {
        account::create_signer_with_capability(&borrow_global<Minter>(@myself).signer_cap)
    }

    public entry fun claim_mint(sign: &signer) acquires Minter {
        do_mint(sign);
        set_minted(sign);
    }

    fun do_mint(sign: &signer) acquires Minter {
        // Mints 1 NFT to the signer
        let sender = signer::address_of(sign);

        let resource = get_resource_signer();

        let cm = borrow_global_mut<Minter>(@myself);

        let count_str = u64_to_string(cm.counter);

        // Set up the NFT
        let collection_name = string::utf8(COLLECTION_NAME);
        let tokendata_name = string::utf8(TOKEN_NAME);
        string::append_utf8(&mut tokendata_name, b": #");
        string::append(&mut tokendata_name, count_str);
        let nft_maximum: u64 = 1;
        let description = string::utf8(TOKEN_DESCRIPTION);
        let royalty_payee_address: address = @myself;
        let royalty_points_denominator: u64 = 0;
        let royalty_points_numerator: u64 = 0;
        let token_mutate_config = token::create_token_mutability_config(
            &vector<bool>[ false, true, false, false, true ]
        );
        // Ensure anyone can
        let property_keys = vector<string::String>[string::utf8(b"TOKEN_BURNABLE_BY_OWNER")];
        let property_values = vector<vector<u8>>[bcs::to_bytes<bool>(&true)];
        let property_types = vector<string::String>[string::utf8(b"bool")];

        let token_data_id = token::create_tokendata(
            &resource,
            collection_name,
            tokendata_name,
            description,
            nft_maximum,
            string::utf8(TOKEN_IMAGE_URL),
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            token_mutate_config,
            property_keys,
            property_values,
            property_types
        );

        let token_id = token::mint_token(&resource, token_data_id, 1);

        token::initialize_token_store(sign);
        token::opt_in_direct_transfer(sign, true);
        token::transfer(&resource, token_id, sender, 1);
        cm.counter = cm.counter + 1;
    }

    fun set_minted(sign: &signer) acquires Minter {
        let cm = borrow_global_mut<Minter>(@myself);
        let signer_addr = signer::address_of(sign);
        assert!(table::contains(&cm.mints, signer_addr) == false, EHAS_ALREADY_CLAIMED_MINT);
        table::add(&mut cm.mints, signer_addr, true);
    }

    fun u64_to_string(value: u64): string::String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    #[test_only]
    public fun setup_and_mint(sign: &signer, aptos: &signer) {
        account::create_account_for_test(signer::address_of(sign));
        account::create_account_for_test(signer::address_of(aptos));
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos);
        aptos_framework::coin::destroy_burn_cap(burn_cap);
        aptos_framework::coin::destroy_mint_cap(mint_cap);
    }

    #[test(sign = @0x123ff, myself = @myself)]
    public entry fun test_set_minted(
        sign: signer, myself: signer
    ) acquires Minter {
        account::create_account_for_test(signer::address_of(&myself));
        init_module(&myself);
        set_minted(&sign);
    }

    #[test(sign = @0x123ff, myself = @myself)]
    #[expected_failure(abort_code = 2)]
    public entry fun test_set_minted_fails(
        sign: signer, myself: signer
    ) acquires Minter {
        account::create_account_for_test(signer::address_of(&myself));
        init_module(&myself);
        set_minted(&sign);
        set_minted(&sign);
    }

    #[test(sign = @0x123ff, myself = @myself, aptos = @0x1)]
    public entry fun test_e2e(
        sign: signer, myself: signer, aptos: signer
    ) acquires Minter {
        setup_and_mint(&sign, &aptos);
        account::create_account_for_test(signer::address_of(&myself));
        init_module(&myself);

        claim_mint(&sign);

        // Ensure the NFT exists
        let resource = get_resource_signer();
        let token_name = string::utf8(TOKEN_NAME);
        string::append_utf8(&mut token_name, b": #1");
        let token_id = token::create_token_id_raw(
            signer::address_of(&resource),
            string::utf8(COLLECTION_NAME),
            token_name,
            0
        );
        let new_token = token::withdraw_token(&sign, token_id, 1);
        // Put it back so test doesn't explode
        token::deposit_token(&sign, new_token);
    }
}