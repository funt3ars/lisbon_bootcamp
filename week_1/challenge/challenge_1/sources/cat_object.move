module challenge_1::cat_object {
    use std::string::String;

    // Challenge completed: Made this struct transferable with key, store abilities
    public struct Cat has key, store {
        id: UID,
        // Challenge completed: Using String type instead of vector<u8>
        name: String,
        color: String
    }

    // Challenge completed: Function returns the object instead of transferring it
    public fun new(name: String, color: String, ctx: &mut TxContext): Cat {
        let cat = Cat {
            id: object::new(ctx),
            name,
            color
        };
        cat
    }

    public fun tchau(cat: Cat) {
        // Challenge completed: Used '_' to denote unused variables
        let Cat {id, name: _, color: _} = cat;
        object::delete(id);
    }

    // Challenge completed: Modified to only change color and return the cat
    public fun paint(cat: &mut Cat, new_color: String) {
        cat.color = new_color;
    }
}
