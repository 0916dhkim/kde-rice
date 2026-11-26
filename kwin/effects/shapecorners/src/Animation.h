#pragma once

#include <QPointer>
#include <chrono>

namespace KWin
{
    class EffectWindow;
}

namespace ShapeCorners
{
    class Window;
    class WindowManager;

    /**
     * @brief Manages active/inactive border & shadow transitions with proper KWin repaint scheduling.
     */
    class Animation
    {
    public:
        Animation();

        /// Called directly from KWin::EffectsHandler::windowActivated.
        void onWindowActivated(KWin::EffectWindow *kwindow);

        /// Updates interpolated visual config for a window during prePaintWindow.
        void update(Window &window);

        /// Schedules next-frame repaints during postPaintScreen for all currently animating windows.
        void schedulePostPaintRepaints(const WindowManager &windowManager);

    private:
        void setActiveWindowChanged(Window *window);
        void startWindowAnimation(Window *window, std::chrono::steady_clock::time_point now, int durationMs);

        QPointer<Window> currentActiveWindow;
        QPointer<Window> lastActiveWindow;
    };
} // namespace ShapeCorners
