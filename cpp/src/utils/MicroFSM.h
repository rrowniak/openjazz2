#ifndef MICROFSM_H
#define MICROFSM_H

#include "utils/Mpl.h"
#include <unordered_map>

template <typename State, typename Event>
class MicroFSM
{
public:
    class Transition
    {
    public:
        State initialState;
        Event event;
        State destinationState;
        Transition(State initialState, Event ev, State destinationState)
            : initialState(initialState)
            , event(ev)
            , destinationState(destinationState)
        { }
    };
    MicroFSM(std::initializer_list<Transition> transitions)
        : currentState(State()) // ???
    {
        for (auto& t: transitions)
        {
            add_transition(t);
        }
    }

    template<typename CollT>
    MicroFSM(const CollT& c, State current)
        : currentState(current)
    {
        for (auto& t: c)
        {
            add_transition(t);
        }
    }

    State GetCurrentState() const
    {
        return currentState;
    }

    bool OnEvent(Event ev)
    {
        auto it = fsm.find(ev);
        if (it != fsm.end())
        {
            auto sti = it->second.find(currentState);
            if (sti != it->second.end())
            {
                // make a transition
                currentState = sti->second;
                return true;
            }
        }
        return false;
    }

private:
    mutable State currentState;
    //
    template <typename T, bool>
    struct HashSelector
    {
        typedef typename T::hash type;
    };

    template <typename T>
    struct HashSelector<T, false>
    {
        typedef typename std::hash<T> type;
    };

    //
    //typedef typename TernaryOp<ContainsHashFunctor<State>::value,
    //    typename State::hash, typename std::hash<State>>::type hash_functor;
    typedef typename HashSelector<State, ContainsHashFunctor<State>::value>::type hash_functor;
    typedef std::unordered_map<State, State, hash_functor> state2state;
    typedef std::unordered_map<Event, state2state> state_map;
    state_map   fsm;

    void add_transition(const Transition& t)
    {
        auto it = fsm.find(t.event);
        auto tpair = std::make_pair(t.initialState, t.destinationState);
        if (it != fsm.end())
        {
            it->second.insert(tpair);
        }
        else
        {
            fsm.insert(std::make_pair(t.event, state2state{tpair}));
        }
    }
};

#endif // MICROFSM_H
