#ifndef ANIMATIONFSM_H
#define ANIMATIONFSM_H

#include "utils/MicroFSM.h"
#include "gfx/Animation.h"
#include "utils/Utils.h"

#include <unordered_map>
#include <vector>
#include <algorithm>
#include <boost/bind.hpp>

enum class DisplayMode
{
    Normal,
    StopAtLastFrame,
    OnlyFirstFrame,
};

enum class SelfInterruptMode
{
    NoSelfInterruption,
    AfterAnimation,
    AfterTimeOut,
    AfterTimeOutOrAnimation
};

template <typename EventT>
struct AnimationState
{
public:
    AnimationState(int uid, Animation a, bool restartAnim = true,
                   SelfInterruptMode intMode = SelfInterruptMode::NoSelfInterruption,
                   std::vector<EventT> evs = std::vector<EventT>(),
                   miliseconds msec = miliseconds())
        : id(uid)
        , anim(a)
        , restartAfterStateBegin(restartAnim)
        , selfInterruptMode(intMode)
        , intEvents(evs)
        , intventTimeout(msec)
    { }
    int GetId() const { return id; }
private:
    int                     id;
    Animation               anim;
    bool                    restartAfterStateBegin;
    SelfInterruptMode       selfInterruptMode;
    std::vector<EventT>     intEvents;
    miliseconds      intventTimeout;
    GameClock::time_point   lastUpdate;

    template <typename EvT> friend class ContrAnim;

    void OnEnter(GameClock::time_point now)
    {
        lastUpdate = now;
    }

    void OnLeave(GameClock::time_point /*now*/)
    {
        if (restartAfterStateBegin)
        {

        }
    }
    void Update(const time_point& now)
    {
        anim.Update(now);
    }
};

// Animation Controller
template <typename EventT>
class ContrAnim
{
public:
    typedef AnimationState<EventT> State;
    typedef MicroFSM<int, EventT> AnimFsm;

    ContrAnim(std::vector<State> sts,
              std::vector<typename AnimFsm::Transition> transitions)
        : fsm(transitions, sts[0].GetId())
    {
        for (auto& s : sts)
        {
            states.insert(std::make_pair(s.GetId(), std::move(s)));
        }
    }

    void OnEvent(EventT e)
    {
        auto tick = GameClock::now();
        getStateAt(fsm.GetCurrentState()).OnLeave(tick);
        fsm.OnEvent(e);
        getStateAt(fsm.GetCurrentState()).OnEnter(tick);
    }
    const Animation& GetCurrent() const
    {
        const auto s = states.find(fsm.GetCurrentState());
        assert(s != states.end());
        return s->second.anim;
    }
    void Update()
    {
        auto s = states.find(fsm.GetCurrentState());
        assert(s != states.end());
        s->second.Update(GameClock::now());
    }
private:
    AnimFsm         fsm;
    typedef std::unordered_map<int, State> event_map;
    event_map       states;

    State& getStateAt(unsigned index)
    {
        auto s = states.find(index);
        assert(s != states.end());
        return s->second;
    }
};

#endif // ANIMATIONFSM_H
