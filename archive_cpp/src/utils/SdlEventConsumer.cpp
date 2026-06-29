#include "SdlEventConsumer.h"

void SdlEventConsumer::OnEvent(SDL_Event* ev)
{
    switch (ev->type)
    {
//        case SDL_ACTIVEEVENT:
//        {
//            switch (ev->active.state)
//            {
//                case SDL_APPMOUSEFOCUS:
//                {
//                    if (ev->active.gain)
//                        OnMouseFocus();
//                    else
//                        OnMouseBlur();
//
//                    break;
//                }
//                case SDL_APPINPUTFOCUS:
//                {
//                    if (ev->active.gain)
//                        OnInputFocus();
//                    else
//                        OnInputBlur();
//
//                    break;
//                }
//                case SDL_APPACTIVE:
//                {
//                    if (ev->active.gain)
//                        OnRestore();
//                    else
//                        OnMinimize();
//
//                    break;
//                }
//            }
//            break;
//        }

        case SDL_KEYDOWN:
        {
            OnKeyDown(ev->key.keysym.sym, ev->key.keysym.mod, 0);
            break;
        }

        case SDL_KEYUP:
        {
            OnKeyUp(ev->key.keysym.sym, ev->key.keysym.mod, 0);
            break;
        }

        case SDL_MOUSEMOTION:
        {
            OnMouseMove(ev->motion.x, ev->motion.y, ev->motion.xrel, ev->motion.yrel,
                        (ev->motion.state & SDL_BUTTON(SDL_BUTTON_LEFT)) != 0,
                        (ev->motion.state & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0,
                        (ev->motion.state & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0);
            break;
        }

        case SDL_MOUSEBUTTONDOWN:
        {
            switch (ev->button.button)
            {
                case SDL_BUTTON_LEFT:
                {
                    OnLButtonDown(ev->button.x, ev->button.y);
                    break;
                }
                case SDL_BUTTON_RIGHT:
                {
                    OnRButtonDown(ev->button.x, ev->button.y);
                    break;
                }
                case SDL_BUTTON_MIDDLE:
                {
                    OnMButtonDown(ev->button.x, ev->button.y);
                    break;
                }
            }
            break;
        }

        case SDL_MOUSEBUTTONUP:
        {
            switch (ev->button.button)
            {
                case SDL_BUTTON_LEFT:
                {
                    OnLButtonUp(ev->button.x, ev->button.y);
                    break;
                }
                case SDL_BUTTON_RIGHT:
                {
                    OnRButtonUp(ev->button.x, ev->button.y);
                    break;
                }
                case SDL_BUTTON_MIDDLE:
                {
                    OnMButtonUp(ev->button.x, ev->button.y);
                    break;
                }
            }
            break;
        }

        case SDL_JOYAXISMOTION:
        {
            OnJoyAxis(ev->jaxis.which, ev->jaxis.axis, ev->jaxis.value);
            break;
        }

        case SDL_JOYBALLMOTION:
        {
            OnJoyBall(ev->jball.which, ev->jball.ball, ev->jball.xrel, ev->jball.yrel);
            break;
        }

        case SDL_JOYHATMOTION:
        {
            OnJoyHat(ev->jhat.which, ev->jhat.hat, ev->jhat.value);
            break;
        }

        case SDL_JOYBUTTONDOWN:
        {
            OnJoyButtonDown(ev->jbutton.which, ev->jbutton.button);
            break;
        }

        case SDL_JOYBUTTONUP:
        {
            OnJoyButtonUp(ev->jbutton.which, ev->jbutton.button);
            break;
        }

        case SDL_QUIT:
        {
            OnExit();
            break;
        }

        case SDL_SYSWMEVENT:
        {
            //Ignore
            break;
        }

//        case SDL_VIDEORESIZE:
//        {
//            OnResize(ev->resize.w, ev->resize.h);
//            break;
//        }
//
//        case SDL_VIDEOEXPOSE:
//        {
//            OnExpose();
//            break;
//        }

        default: {
            OnUser(ev->user.type, ev->user.code, ev->user.data1, ev->user.data2);
            break;
        }
    }
}
