#pragma once

#include <QObject>
#include <chrono>
#include <effect/offscreeneffect.h>
#include "Shader.h"

namespace ShapeCorners
{
    class Animation;
    class WindowManager;

    class Effect final : public KWin::OffscreenEffect
    {
        Q_OBJECT

    public:
        Effect();
        Effect(const Effect &)             = delete;
        Effect(const Effect &&)            = delete;
        Effect &operator=(const Effect &)  = delete;
        Effect &operator=(const Effect &&) = delete;
        ~Effect() override;

        static bool supported();

        void reconfigure(ReconfigureFlags flags) override;

#if KWIN_EFFECT_API_VERSION >= 237
#if KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 6, 80)
        void prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *w, KWin::WindowPrePaintData &data) override;
#else
        void prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *w, KWin::WindowPrePaintData &data,
                            std::chrono::milliseconds time) override;
#endif
#else
        void prePaintWindow(KWin::EffectWindow *w, KWin::WindowPrePaintData &data,
                            std::chrono::milliseconds time) override;
#endif

        void postPaintScreen() override;

#if KWIN_EFFECT_API_VERSION >= 237 && KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 7, 80)
        bool drawWindow(
#else
        void drawWindow(
#endif
                const KWin::RenderTarget &RenderTarget, const KWin::RenderViewport &viewport, KWin::EffectWindow *w,
                int mask,
#if KWIN_EFFECT_API_VERSION >= 237
                const KWin::Region &region,
#else
                const QRegion &region,
#endif
                KWin::WindowPaintData &data) override;

        [[nodiscard]]
        int requestedEffectChainPosition() const override
        {
            return 99;
        }

        [[nodiscard]]
        bool blocksDirectScanout() const override
        {
            return false;
        }

        [[nodiscard]]
        bool isActive() const override
        {
            return m_shaderManager.IsValid();
        }

        [[nodiscard]]
        bool provides(const Feature feature) override
        {
            return feature == Nothing;
        }

    private Q_SLOTS:
        void windowAdded(KWin::EffectWindow *kwindow);
        void windowActivated(KWin::EffectWindow *kwindow);

    private:
        Shader m_shaderManager;
        std::unique_ptr<WindowManager> m_windowManager;
        std::unique_ptr<Animation> m_animation;
    };
} // namespace ShapeCorners
