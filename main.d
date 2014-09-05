import bfs;
import klondike;

void main()
{
    import bfs;
    import klondike;
    import std.stdio : writeln;

    State initial;
    with(AllCards)
    {
        initial.waste.cards = [C9, SQ, CA, D6, S9, C5, DA, H7, CQ, DJ, CJ, HK, HA, H2, H5, D3, D8, H6, C2, DQ, ST, D7, SK, H4];
        initial.waste.currentIdx = initial.waste.cards.length - 1;

        initial.piles[0].cards = [S3];
        initial.piles[0].hidden = 0;
        
        initial.piles[0].cards = [D4, H8];
        initial.piles[0].hidden = 1;

        initial.piles[0].cards = [H3, D2, SA];
        initial.piles[0].hidden = 2;

        initial.piles[0].cards = [S5, S8, D9, S2];
        initial.piles[0].hidden = 3;

        initial.piles[0].cards = [C4, S7, HT, HJ, CK];
        initial.piles[0].hidden = 4;

        initial.piles[0].cards = [HQ, DK, H9, DT, C7, CT];
        initial.piles[0].hidden = 5;

        initial.piles[0].cards = [SJ, S6, C6, C3, S4, C8, D5];
        initial.piles[0].hidden = 6;
    }
    bfs.bfs!(getAvailableMoves, applyMove, finished)(initial).writeln;
}
