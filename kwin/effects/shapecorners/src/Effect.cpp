#include "Effect.h"
#include <QDebug>
#include <core/output.h>
#include <core/renderviewport.h>
#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <opengl/glutils.h>
#include "Animation.h"
#include "Config.h"
#include "Window.h"
#include "WindowManager.h"

#if KWIN_PLUGIN_VERSION_NUM < QT_VERSION_CHECK(6, 6, 80)
#include "Utils.h"
#endif

ShapeCorners::Effect::Effect()
{
    Config::self()->read();
    m_animation = std::make_unique<Animation>();

    if (m_shaderManager.IsValid()) {
        m_windowManager = std::make_unique<WindowManager>();
        connect(KWin::effects, &KWin::EffectsHandler::windowAdded, this, &Effect::windowAdded);
        connect(KWin::effects, &KWin::EffectsHandler::windowActivated, this, &Effect::windowActivated);
    }
}

ShapeCorners::Effect::~Effect() = default;

void ShapeCorners::Effect::reconfigure(const ReconfigureFlags flags)
{
    Q_UNUSED(flags)

    Config::self()->read();

    if (!m_animation) {
        m_animation = std::make_unique<Animation>();
    }

    // Live-reload GLSL fragment shader on KWin reconfigure without logout
    if (m_shaderManager.Reload() && m_windowManager) {
        for (const auto &[kwindow, managed] : m_windowManager->getWindows()) {
            if (managed && managed->w != nullptr) {
                setShader(managed->w, m_shaderManager.GetShader().get());
            }
        }
    }

    KWin::effects->addRepaintFull();
}

#if KWIN_EFFECT_API_VERSION >= 237
#if KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 6, 80)
void ShapeCorners::Effect::prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *kwindow,
                                          KWin::WindowPrePaintData &data)
#else
void ShapeCorners::Effect::prePaintWindow(KWin::RenderView *view, KWin::EffectWindow *kwindow,
                                          KWin::WindowPrePaintData &data, std::chrono::milliseconds time)
#endif
#else
void ShapeCorners::Effect::prePaintWindow(KWin::EffectWindow *kwindow, KWin::WindowPrePaintData &data,
                                          std::chrono::milliseconds time)
#endif
{
    auto *window = m_windowManager ? m_windowManager->findWindow(kwindow) : nullptr;

    if (!m_shaderManager.IsValid() || window == nullptr || !window->hasEffect(true)) {
#if KWIN_EFFECT_API_VERSION >= 237
#if KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 6, 80)
        OffscreenEffect::prePaintWindow(view, kwindow, data);
#else
        OffscreenEffect::prePaintWindow(view, kwindow, data, time);
#endif
#else
        OffscreenEffect::prePaintWindow(kwindow, data, time);
#endif
        return;
    }

    // Interpolate current frame's corner/outline/shadow config (next-frame repaints are
    // scheduled properly in postPaintScreen()).
    m_animation->update(*window);

    if (window->hasRoundCorners()) {
#if KWIN_PLUGIN_VERSION_NUM < QT_VERSION_CHECK(6, 6, 80)
        const auto geo  = (kwindow->frameGeometry() * kwindow->screen()->scale()).toRect();
        const auto size = (int)(window->currentConfig.cornerRadius * kwindow->screen()->scale());
#if KWIN_EFFECT_API_VERSION >= 237
        KWin::Region reg{};
#else
        QRegion reg{};
#endif
        reg += QRect(geo.x(), geo.y(), size, size);
        reg += QRect(geo.x() + geo.width() - size, geo.y(), size, size);
        reg += QRect(geo.x(), geo.y() + geo.height() - size, size, size);
        reg += QRect(geo.x() + geo.width() - size, geo.y() + geo.height() - size, size, size);
#if KWIN_EFFECT_API_VERSION >= 237
        data.deviceOpaque -= reg;
        data.devicePaint += reg;
#else
        data.opaque -= reg;
        data.paint += reg;
#endif
#endif

        if (Config::markWindowsTranslucent()) {
            data.setTranslucent();
        }
    }

#if KWIN_EFFECT_API_VERSION >= 237
#if KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 6, 80)
    OffscreenEffect::prePaintWindow(view, kwindow, data);
#else
    OffscreenEffect::prePaintWindow(view, kwindow, data, time);
#endif
#else
    OffscreenEffect::prePaintWindow(kwindow, data, time);
#endif
}

void ShapeCorners::Effect::postPaintScreen()
{
    if (m_animation && m_windowManager) {
        m_animation->schedulePostPaintRepaints(*m_windowManager);
    }
    KWin::effects->postPaintScreen();
}

bool ShapeCorners::Effect::supported()
{
    return KWin::effects->isOpenGLCompositing();
}

#if KWIN_EFFECT_API_VERSION >= 237 && KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 7, 80)
bool ShapeCorners::Effect::drawWindow(
#else
void ShapeCorners::Effect::drawWindow(
#endif
        const KWin::RenderTarget &renderTarget, const KWin::RenderViewport &viewport, KWin::EffectWindow *kwindow,
        int mask,
#if KWIN_EFFECT_API_VERSION >= 237
        const KWin::Region &region,
#else
        const QRegion &region,
#endif
        KWin::WindowPaintData &data)
{
    const auto *window = m_windowManager ? m_windowManager->findWindow(kwindow) : nullptr;

    if (!m_shaderManager.IsValid() || window == nullptr || !window->hasEffect(true)) {
        unredirect(kwindow);
#if KWIN_EFFECT_API_VERSION >= 237 && KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 7, 80)
        return OffscreenEffect::drawWindow(renderTarget, viewport, kwindow, mask, region, data);
#else
        OffscreenEffect::drawWindow(renderTarget, viewport, kwindow, mask, region, data);
        return;
#endif
    }

    const auto scale = kwindow->screen()->scale();

    redirect(kwindow);
    setShader(kwindow, m_shaderManager.GetShader().get());
    m_shaderManager.Bind(*window, scale);
    glActiveTexture(GL_TEXTURE0);

#if KWIN_EFFECT_API_VERSION >= 237 && KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 7, 80)
    const bool result = OffscreenEffect::drawWindow(renderTarget, viewport, kwindow, mask, region, data);
#else
    OffscreenEffect::drawWindow(renderTarget, viewport, kwindow, mask, region, data);
#endif
    m_shaderManager.Unbind();
#if KWIN_EFFECT_API_VERSION >= 237 && KWIN_PLUGIN_VERSION_NUM >= QT_VERSION_CHECK(6, 7, 80)
    return result;
#endif
}

void ShapeCorners::Effect::windowAdded(KWin::EffectWindow *kwindow)
{
    if (m_windowManager && m_windowManager->addWindow(kwindow)) {
        redirect(kwindow);
        setShader(kwindow, m_shaderManager.GetShader().get());
    }
}

void ShapeCorners::Effect::windowActivated(KWin::EffectWindow *kwindow)
{
    if (m_animation) {
        m_animation->onWindowActivated(kwindow);
    }
}
