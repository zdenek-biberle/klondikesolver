module klondike;

enum Colour
{
    Red,
    Black,
}

enum Suit : ushort
{
    Clubs,
    Diamonds,
    Hearts,
    Spades,
}

enum Rank : ushort
{
    RA,
    R2,
    R3,
    R4,
    R5,
    R6,
    R7,
    R8,
    R9,
    RT,
    RJ,
    RQ,
    RK,
}

private int cmpSizeT(size_t a, size_t b)
{
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
}

pure struct Card
{
    Suit suit;
    Rank rank;

    const int opCmp(ref const Card other)
    {
        int diff = suit - other.suit;
        if (diff != 0) return diff;
        return rank - other.rank;
    }
}

string generateCards()
{
    import std.array : appender;
    import std.range : put;
    import std.string : format;
    import std.typetuple : TypeTuple;
    import std.traits : EnumMembers;

    auto result = appender!string();
    put(result, "enum AllCards {");

    foreach (suit; __traits(allMembers, Suit))
    {
        foreach (rank; __traits(allMembers, Rank))
        {
            auto name = suit[0] ~ rank[1..$];
            auto decl = "%s = Card(Suit.%s, Rank.%s),".format(name, suit, rank);
            put(result, decl);
        }
    }
    
    put(result, "}");
    return result.data;
}

mixin(generateCards);

pure struct Foundation
{
    const(Card)[] cards;

    const int opCmp(ref const Foundation other)
    {
        import std.algorithm : cmp;
        return cards.cmp(other.cards);
    }

    invariant()
    {
        import std.algorithm : map, startsWith;
        import std.traits : EnumMembers;
            
        assert([EnumMembers!Rank].startsWith(cards.map!(x => x.rank)));
    }
}

pure struct Pile
{
    const(Card)[] cards;
    size_t hidden;

    const int opCmp(ref const Pile other)
    {
        import std.algorithm : cmp;
        int diff = cards.cmp(other.cards);
        if (diff != 0) return diff;
        return cmpSizeT(hidden, other.hidden);
    }

    invariant()
    {
        import std.array : empty;
        assert(cards.empty || hidden < cards.length);
    }
}

pure struct Waste
{
    const(Card)[] cards;
    size_t currentIdx;

    const int opCmp(ref const Waste other)
    {
        import std.algorithm : cmp;
        int diff = cards.cmp(other.cards);
        if (diff != 0) return diff;
        return cmpSizeT(currentIdx, other.currentIdx);
    }

    invariant()
    {
        import std.array : empty;
        assert(cards.empty || currentIdx < cards.length);
    }
}

pure struct State
{
    Foundation[4] foundations;
    Pile[7] piles;
    Waste waste;

    const int opCmp(ref const State other)
    {
        import std.range : zip;

        foreach (f; zip(foundations[], other.foundations[]))
        {
            int diff = f[0].opCmp(f[1]);
            if (diff != 0) return diff;
        }

        foreach (p; zip(piles[], other.piles[]))
        {
            int diff = p[0].opCmp(p[1]);
            if (diff != 0) return diff;
        }

        return waste.opCmp(other.waste);
    }

    invariant()
    {
        foreach (f; foundations) assert(&f);
        foreach (p; piles) assert(&p);
        assert(&waste);
    }
}

@property pure nothrow
{
    Colour colour(in Suit suit)
    {
        with(Suit) final switch (suit)
        {
            case Clubs: case Spades: return Colour.Black;
            case Hearts: case Diamonds: return Colour.Red;
        }
    }
    
    Colour colour(in Card card)
    {
        return card.suit.colour;
    }
    
    bool finished(in Foundation foundation)
    {
        assert(&foundation);
        return foundation.hasCards && foundation.cards[$-1].rank == Rank.RK;
    }
    
    bool finished(in State state)
    {
        import std.algorithm : all;
        return state.foundations[].all!(x => x.finished);
    }
    
    bool hasCards(in Foundation foundation)
    {
        import std.array : empty;
        return !foundation.cards.empty;
    }
    
    bool hasCards(in Pile pile)
    {
        import std.array : empty;
        return !pile.cards.empty;
    }
    
    bool hasCards(in Waste waste)
    {
        import std.array : empty;
        return !waste.cards.empty;
    }

    Card current(in Waste waste)
    {
        assert(&waste);
        assert(waste.hasCards, "waste has got no cards");  
        return waste.cards[waste.currentIdx];
    }

    Card current(in Foundation foundation)
    {
        assert(&foundation);
        assert(foundation.hasCards, "foundation has got no cards");
        return foundation.cards[$-1];
    }

    Card current(in Pile pile)
    {
        assert(&pile);
        assert(pile.hasCards, "pile has got no cards");
        return pile.cards[$-1];
    }

    size_t visible(in Pile pile)
    {
        return pile.cards.length - pile.hidden;
    }
}

unittest
{
    assert(Suit.Diamonds.colour == Colour.Red);
    assert(Suit.Hearts.colour == Colour.Red);
    assert(Suit.Clubs.colour == Colour.Black);
    assert(Suit.Spades.colour == Colour.Black);
}

enum MovePosition
{
    foundation,
    pile,
    waste,
}

struct Move
{
    MovePosition from;
    MovePosition to;
    size_t howMany;
    size_t fromIdx;
    size_t toIdx;

    invariant()
    {
        if (howMany != 1)
        {
            assert(from == MovePosition.pile);
            assert(to == MovePosition.pile);
        }

        if (to == MovePosition.waste)
        {
            assert(from == MovePosition.waste);
        }
    }
}

auto getAvailableMoves(in State state)
{
    import std.algorithm;
    import std.typecons;
    import std.functional;
    import std.range;
    import std.traits : Unqual;

    alias withIndex = pipe!(
        partial!(zip, iota(size_t.max)),
        map!(x => Tuple!(size_t, "idx", Unqual!(typeof(x[1])), "value")(x))
    );

    // find moves to foundations
    auto toFoundations = 
        withIndex(state.piles[])
        .filter!(p => p.value.hasCards)
        .map!(p => tuple(MovePosition.pile, p.idx, cast(Card) p.value.cards[$-1]))
        .chain(
            withIndex(state.waste.only)
            .filter!(w => w.value.hasCards)
            .map!(w => tuple(MovePosition.waste, w.idx, w.value.current))
        )
        .cartesianProduct(
            withIndex(state.foundations[])
            .filter!(f => f.value.hasCards)
            .chain(
                withIndex(state.foundations[])
                .filter!(f => !f.value.hasCards)
                .takeOne
            )
        )
        .filter!(c => 
            c[1].value.hasCards
            // move only same colour and higher rank if there 
            // are cards on the foundation
            ? c[0][2].colour == c[1].value.current.colour
                && c[0][2].rank == c[1].value.current.rank + 1
            // move only aces if there are no cards on the foundation
            : c[0][2].rank == Rank.RA
        )
        .map!(c => Move(
            c[0][0], 
            MovePosition.foundation,
            1,
            c[0][1],
            c[1].idx
        ));

    import std.stdio;     

    // find moves to piles
    auto toPiles =
        withIndex(state.piles[])
        .filter!(p => p.value.hasCards)
        .map!(p => 
            withIndex(p.value.cards)[p.value.hidden..$]
            .map!(c => tuple(MovePosition.pile, p.idx, c.value, p.value.cards.length - c.idx, c.idx))
        )
        .joiner
        .chain(
            withIndex(state.foundations[])
            .filter!(f => f.value.hasCards)
            .map!(f => tuple(MovePosition.foundation, f.idx, f.value.current, size_t(1), size_t(0))),

            state.waste
            .only
            .filter!(w => w.hasCards)
            .map!(w => tuple(MovePosition.waste, size_t(0), w.current, size_t(1), size_t(0)))
        )
        .cartesianProduct(
            withIndex(state.piles[])
            .filter!(p => p.value.hasCards)
            .chain(
                withIndex(state.piles[])
                .filter!(p => !p.value.hasCards)
                .takeOne
            )
        )
        .filter!(m =>
            m[1].value.hasCards
                ? m[1].value.current.colour != m[0][2].colour
                    && m[1].value.current.rank == m[0][2].rank + 1
                // Move only kings when there are no cards on the foundation
                // and when the king isn't already on the bottom
                : m[0][2].rank == Rank.RK 
                    && !(m[0][0] == MovePosition.pile && m[0][4] == 0) 
        )
        .map!(m => Move(
            m[0][0],
            MovePosition.pile,
            m[0][3],
            m[0][1],
            m[1].idx
        ));

    // find moves on waste
    auto toWaste = 
        state.waste
        .only
        .filter!(w => w.cards.length > 1)
        .map!(w => Move(
            MovePosition.waste,
            MovePosition.waste,
            1,
            0,
            0
        ));

    return chain(toFoundations, toPiles, toWaste);
}

unittest
{
    State state;
    state.foundations[0].cards = [Card(Suit.Clubs, Rank.RA)];
    state.foundations[1].cards = [Card(Suit.Diamonds, Rank.RA), Card(Suit.Diamonds, Rank.R2)];
    state.piles[0].cards = [Card(Suit.Clubs, Rank.R2)];
    state.piles[1].cards = [Card(Suit.Hearts, Rank.RA)];
    state.piles[2].cards = [Card(Suit.Diamonds, Rank.R3)];

    state.getAvailableMoves;
}

pure State applyMove(in Move move, State state)
{
    assert(&move);
    assert(&state);

    ref const(Card)[] chooseCards(MovePosition position, size_t idx)
    {
        with(MovePosition) final switch(position)
        {
            case foundation: return state.foundations[idx].cards;
            case pile: return state.piles[idx].cards;
            case waste: return state.waste.cards;
        }
    }

    auto srcCards = &chooseCards(move.from, move.fromIdx);
    auto dstCards = &chooseCards(move.to, move.toIdx);

    const(Card)[] movedCards;

    if (move.from == MovePosition.waste)
    {
        if (move.to == MovePosition.waste)
        {
            state.waste.currentIdx++;
            state.waste.currentIdx %= state.waste.cards.length;
        }
        else
        {
            auto idx = state.waste.currentIdx;
            movedCards = (*srcCards)[idx..idx+1];
            (*srcCards) = (*srcCards)[0..idx] ~
                (*srcCards)[idx + 1..$];
        }
    }
    else
    {
        movedCards = (*srcCards)[$ - move.howMany .. $];
        (*srcCards).length -= move.howMany;   
    }

    if (move.to != MovePosition.waste)
    {
        (*dstCards) ~= movedCards;
    }

    return state;
}
