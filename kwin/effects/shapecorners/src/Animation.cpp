#include "Animation.h"
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

    if (animationDuration <= 0 || remainingMs <= 0) {
        window.lastAnimationDuration = 0;
        window.isAnimating           = false;
        window.currentConfig         = window.isActive() ? activeConfig : inactiveConfig;
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

    lastActiveWindow    = currentActiveWindow;
    currentActiveWindow = window;

    startWindowAnimation(currentActiveWindow, now, durationMs);
    startWindowAnimation(lastActiveWindow, now, durationMs);
}
