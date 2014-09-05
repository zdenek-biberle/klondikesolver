module bfs;

import std.range : ElementType, isInputRange;

auto bfs(
    alias getOps, 
    alias applyOp, 
    alias isFinal, 
    State, 
    Op = ElementType!(typeof(getOps(State.init))))
    (State initial)
if (isInputRange!(typeof(getOps(State.init))))
{
    struct PathNode
    {
        PathNode* parent;
        State state;
        Op operator;
        size_t depth;
    }

    struct ResultNode
    {
        State state;
        Op operator;
    }
    
    import std.array : appender;
    import std.container : make, DList, RedBlackTree;

    auto visitedStates = make!(RedBlackTree!State)();
    auto queue = make!(DList!(PathNode*))();

    queue.insertBack(new PathNode(null, initial, Op.init, 0));
    visitedStates.insert(initial);

    bool success = false;


    while (!queue.empty && !success)
    {
        auto node = queue.front();

        if (isFinal(node.state))
        {
            success = true;
        }
        else
        {
            foreach (op; getOps(node.state))
            {
                auto substate = applyOp(op, node.state);
                if (substate !in visitedStates)
                {
                    visitedStates.insert(substate);
                    queue.insertBack(new PathNode(node, substate, op, node.depth + 1));
                }
            }
            queue.removeFront();
        }
    }

    auto depth = success ? queue.front.depth + 1: 0;

    import std.algorithm : map, copy, until;
    import std.array : uninitializedArray;
    import std.range : recurrence, retro;

    auto result = uninitializedArray!(ResultNode[])(depth);

    if (success)
    {
        queue
            .front
            .recurrence!((a,n) => a[n-1].parent)
            .until(null)
            .map!(a => ResultNode(a.state, a.operator))
            .copy(result);
    }

    return result.retro;
}

unittest
{
    import std.algorithm : equal, map;
    import std.range : only;
    import std.stdio;
    bfs!(s => only(1, -1), (o, s) => s + o, s => s == 1)(-2)
        .map!(x => x.state)
        .equal([-2, -1, 0, 1]);
}
