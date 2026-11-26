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

void ShapeCorners::Animation::onWindowActivated(KWin::EffectWindow *kwindow)
{
    lastActivateSignalTime = steady_clock::now();
    hasActivateSignal = true;

    if (Config::debugTimings()) {
        const QString cap = kwindow ? kwindow->caption().left(40) : QStringLiteral("<null>");
        qWarning().noquote() << QStringLiteral("[shapecorners-diag] windowActivated win=\"%1\" dur_cfg=%2ms")
                                    .arg(cap)
                                    .arg(Config::animationDuration());
    }

    auto *const activeWindow = (WindowManager::instance() != nullptr)
        ? WindowManager::instance()->findWindow(kwindow)
        : nullptr;
    if (activeWindow != currentActiveWindow) {
        setActiveWindowChanged(activeWindow);
    }
}

void ShapeCorners::Animation::update(Window &window)
{
    // Fallback detection in case active window changed before windowAdded completed.
    const auto *const active        = KWin::effects->activeWindow();
    const auto *const currentActive = currentActiveWindow != nullptr ? currentActiveWindow->w : nullptr;
    if (active != currentActive && WindowManager::instance() != nullptr) {
        auto *const activeWindow = WindowManager::instance()->findWindow(active);
        if (activeWindow != currentActiveWindow) {
            setActiveWindowChanged(activeWindow);
        }
    }

    const auto activeConfig   = WindowConfig::activeWindowConfig();
    const auto inactiveConfig = WindowConfig::inactiveWindowConfig();

    if (!window.isAnimating) {
        window.currentConfig = window.isActive() ? activeConfig : inactiveConfig;
        return;
    }

    const auto now               = steady_clock::now();
    const int  animationDuration = Config::animationDuration();
    const long elapsedMs         = duration_cast<milliseconds>(now - window.lastActiveChangedTime).count();
    const long remainingMs       = animationDuration - elapsedMs;

    if (Config::debugTimings()) {
        auto &diag = diagByWindow[&window];
        const long gapMs = diag.hasLastFrame
            ? duration_cast<milliseconds>(now - diag.lastFrame).count()
            : -1;
        const long sinceActMs = hasActivateSignal
            ? duration_cast<milliseconds>(now - lastActivateSignalTime).count()
            : -1;
        diag.lastFrame = now;
        diag.hasLastFrame = true;
        diag.frameCount += 1;
        const QString cap = window.w ? window.w->caption().left(32) : QStringLiteral("<null>");
        qWarning().noquote() << QStringLiteral("[shapecorners-diag] frame win=\"%1\" active=%2 n=%3 since_act=%4ms gap=%5ms rem=%6ms")
                                    .arg(cap)
                                    .arg(window.isActive() ? 1 : 0)
                                    .arg(diag.frameCount)
                                    .arg(sinceActMs)
                                    .arg(gapMs)
                                    .arg(std::max<long>(0, remainingMs));
    }

    if (animationDuration <= 0 || remainingMs <= 0) {
        window.lastAnimationDuration = 0;
        window.isAnimating           = false;
        window.currentConfig         = window.isActive() ? activeConfig : inactiveConfig;
        diagByWindow.remove(&window);
        return;
    }

    window.lastAnimationDuration = remainingMs;
    const float remainingRatio   = static_cast<float>(remainingMs) / static_cast<float>(animationDuration);
    const auto  configDiff       = activeConfig - inactiveConfig;
    const auto  deltaConf        = configDiff * remainingRatio;

    if (window.isActive()) {
        window.currentConfig = activeConfig - deltaConf;
    } else {
        window.currentConfig = inactiveConfig + deltaConf;
    }
}

void ShapeCorners::Animation::schedulePostPaintRepaints(const WindowManager &windowManager)
{
    for (const auto &[kwindow, managed] : windowManager.getWindows()) {
        if (managed && managed->isAnimating && managed->w != nullptr) {
            managed->w->addRepaintFull();
        }
    }
}

void ShapeCorners::Animation::startWindowAnimation(Window *window, const steady_clock::time_point now, const int durationMs)
{
    if (window == nullptr || window->w == nullptr) {
        return;
    }
    diagByWindow.remove(window);
    if (durationMs <= 0) {
        window->isAnimating           = false;
        window->lastAnimationDuration = 0;
        window->currentConfig         = window->isActive()
            ? WindowConfig::activeWindowConfig()
            : WindowConfig::inactiveWindowConfig();
        window->w->addRepaintFull();
        return;
    }
    window->lastActiveChangedTime = now;
    window->lastAnimationDuration = durationMs;
    window->isAnimating           = true;
    window->w->addRepaintFull();
}

void ShapeCorners::Animation::setActiveWindowChanged(Window *window)
{
    const auto now        = steady_clock::now();
    const int  durationMs = Config::animationDuration();

    if (Config::debugTimings()) {
        const long delayMs = hasActivateSignal
            ? duration_cast<milliseconds>(now - lastActivateSignalTime).count()
            : -1;
        const QString curCap  = (window && window->w) ? window->w->caption().left(32) : QStringLiteral("<null>");
        const QString prevCap = (currentActiveWindow && currentActiveWindow->w)
            ? currentActiveWindow->w->caption().left(32)
            : QStringLiteral("<null>");
        qWarning().noquote() << QStringLiteral("[shapecorners-diag] setActiveWindowChanged delay_since_act=%1ms new=\"%2\" prev=\"%3\"")
                                    .arg(delayMs)
                                    .arg(curCap)
                                    .arg(prevCap);
    }

    lastActiveWindow    = currentActiveWindow;
    currentActiveWindow = window;

    startWindowAnimation(currentActiveWindow, now, durationMs);
    startWindowAnimation(lastActiveWindow, now, durationMs);
}
