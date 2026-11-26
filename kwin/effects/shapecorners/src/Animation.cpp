//
// Created by matin on 8/3/25.
//

#include "Animation.h"
#include <QDebug>
#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include "Config.h"
#include "Window.h"
#include "WindowConfig.h"
#include "WindowManager.h"

using namespace std::chrono;

ShapeCorners::Animation::Animation() = default;

void ShapeCorners::Animation::noteWindowActivated(KWin::EffectWindow *w)
{
    lastActivateSignalTime = steady_clock::now();
    hasActivateSignal = true;
    const QString cap = w ? w->caption().left(40) : QStringLiteral("<null>");
    qWarning().noquote() << QStringLiteral("[shapecorners-diag] windowActivated win=%1 dur_cfg=%2ms")
                                .arg(cap)
                                .arg(Config::animationDuration());
}

void ShapeCorners::Animation::update(Window &window)
{
    // If the active window has changed, start a new animation cycle.
    const auto *const active        = KWin::effects->activeWindow();
    const auto *const currentActive = currentActiveWindow != nullptr ? currentActiveWindow->w : nullptr;
    if (active != currentActive) {
        auto *const activeWindow = WindowManager::instance()->findWindow(active);
        setActiveWindowChanged(activeWindow);
    }

    // Fetch the current active and inactive configs from the palette once per update.
    const auto activeConfig   = WindowConfig::activeWindowConfig();
    const auto inactiveConfig = WindowConfig::inactiveWindowConfig();

    // If not animating, skip update.
    if (!window.isAnimating) {
        window.currentConfig = window.isActive() ? activeConfig : inactiveConfig;
        return;
    }

    const auto nowSteady = steady_clock::now();
    auto &diag = diagByWindow[&window];
    const long gapMs = diag.hasLastFrame
        ? duration_cast<milliseconds>(nowSteady - diag.lastFrame).count()
        : -1;
    const long sinceActMs = hasActivateSignal
        ? duration_cast<milliseconds>(nowSteady - lastActivateSignalTime).count()
        : -1;
    diag.lastFrame = nowSteady;
    diag.hasLastFrame = true;
    diag.frameCount += 1;
    const QString cap = window.w ? window.w->caption().left(32) : QStringLiteral("<null>");

    // If animation duration is zero, stop animating and set configs to final state.
    if (window.lastAnimationDuration == 0) {
        window.isAnimating = false;
        qWarning().noquote() << QStringLiteral("[shapecorners-diag] end win=\"%1\" active=%2 frames=%3 since_act=%4ms gap=%5ms")
                                    .arg(cap)
                                    .arg(window.isActive() ? 1 : 0)
                                    .arg(diag.frameCount)
                                    .arg(sinceActMs)
                                    .arg(gapMs);
        diagByWindow.remove(&window);
        return;
    }

    // Calculate remaining animation duration.
    const auto now               = system_clock::now();
    const auto animationDuration = Config::animationDuration();
    window.lastAnimationDuration =
            animationDuration + duration_cast<milliseconds>(window.lastActiveChangedTime - now).count();

    // If animation is over, set configs to their final values.
    if (window.lastAnimationDuration < 0) {
        window.lastAnimationDuration = 0;
        window.currentConfig         = window.isActive() ? activeConfig : inactiveConfig;
        qWarning().noquote() << QStringLiteral("[shapecorners-diag] frame win=\"%1\" active=%2 n=%3 since_act=%4ms gap=%5ms rem=0ms (done)")
                                    .arg(cap)
                                    .arg(window.isActive() ? 1 : 0)
                                    .arg(diag.frameCount)
                                    .arg(sinceActMs)
                                    .arg(gapMs);
        return;
    }

    qWarning().noquote() << QStringLiteral("[shapecorners-diag] frame win=\"%1\" active=%2 n=%3 since_act=%4ms gap=%5ms rem=%6ms")
                                .arg(cap)
                                .arg(window.isActive() ? 1 : 0)
                                .arg(diag.frameCount)
                                .arg(sinceActMs)
                                .arg(gapMs)
                                .arg(window.lastAnimationDuration);

    // Interpolate between active and inactive configs based on animation progress.
    const auto deltaTime  = static_cast<float>(window.lastAnimationDuration) / static_cast<float>(animationDuration);
    const auto configDiff = activeConfig - inactiveConfig;
    const auto deltaConf  = configDiff * deltaTime;

    if (window.isActive()) {
        window.currentConfig = activeConfig - deltaConf;
    } else {
        window.currentConfig = inactiveConfig + deltaConf;
    }
    window.isAnimating = true;
}

void ShapeCorners::Animation::setActiveWindowChanged(Window *window)
{
    const long delayMs = hasActivateSignal
        ? duration_cast<milliseconds>(steady_clock::now() - lastActivateSignalTime).count()
        : -1;
    const QString curCap = (window && window->w) ? window->w->caption().left(32) : QStringLiteral("<null>");
    const QString prevCap = (currentActiveWindow && currentActiveWindow->w)
        ? currentActiveWindow->w->caption().left(32)
        : QStringLiteral("<null>");
    qWarning().noquote() << QStringLiteral("[shapecorners-diag] setActiveWindowChanged delay_since_act=%1ms new=\"%2\" prev=\"%3\" new_was_anim=%4 prev_was_anim=%5")
                                .arg(delayMs)
                                .arg(curCap)
                                .arg(prevCap)
                                .arg((window && window->isAnimating) ? 1 : 0)
                                .arg((currentActiveWindow && currentActiveWindow->isAnimating) ? 1 : 0);

    lastActiveWindow    = currentActiveWindow;
    currentActiveWindow = window;

    // If animation is disabled, set the final configs and repaint both windows in full.
    if (Config::animationDuration() == 0) {
        if (currentActiveWindow != nullptr) {
            currentActiveWindow->currentConfig = WindowConfig::activeWindowConfig();
            currentActiveWindow->w->addRepaintFull();
        }
        if (lastActiveWindow != nullptr) {
            lastActiveWindow->currentConfig = WindowConfig::inactiveWindowConfig();
            lastActiveWindow->w->addRepaintFull();
        }
        return;
    }

    // If not animating, start a new animation cycle for the newly activated window.
    if ((currentActiveWindow != nullptr) && !currentActiveWindow->isAnimating) {
        currentActiveWindow->lastActiveChangedTime = system_clock::now();
        currentActiveWindow->lastAnimationDuration = Config::animationDuration();
        currentActiveWindow->isAnimating           = currentActiveWindow->lastAnimationDuration > 0;
        diagByWindow.remove(currentActiveWindow);
    }

    // If not animating, start a new animation cycle for the non-activated window.
    if ((lastActiveWindow != nullptr) && !lastActiveWindow->isAnimating) {
        lastActiveWindow->lastActiveChangedTime = system_clock::now();
        lastActiveWindow->lastAnimationDuration = Config::animationDuration();
        lastActiveWindow->isAnimating           = lastActiveWindow->lastAnimationDuration > 0;
        diagByWindow.remove(lastActiveWindow);
    }
}
