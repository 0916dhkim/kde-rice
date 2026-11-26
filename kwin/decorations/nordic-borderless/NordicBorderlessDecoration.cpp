#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/Decoration>
#include <KPluginFactory>
#include <QMarginsF>
#include <QPainter>
#include <QRectF>

class NordicBorderlessDecoration : public KDecoration3::Decoration
{
    Q_OBJECT

public:
    explicit NordicBorderlessDecoration(QObject *parent = nullptr, const QVariantList &args = QVariantList())
        : KDecoration3::Decoration(parent, args)
    {
    }

    ~NordicBorderlessDecoration() override = default;

    bool init() override
    {
        auto *w = window();
        if (!w) {
            return false;
        }

        setOpaque(false);
        setTitleBar(QRectF());
        setBorders(QMarginsF(0.0, 0.0, 0.0, 0.0));
        setState([](KDecoration3::DecorationState *state) {
            state->setBorders(QMarginsF(0.0, 0.0, 0.0, 0.0));
        });

        updateResizeBorders();

        connect(w, &KDecoration3::DecoratedWindow::maximizedChanged,
                this, &NordicBorderlessDecoration::updateResizeBorders);
        connect(w, &KDecoration3::DecoratedWindow::maximizedHorizontallyChanged,
                this, &NordicBorderlessDecoration::updateResizeBorders);
        connect(w, &KDecoration3::DecoratedWindow::maximizedVerticallyChanged,
                this, &NordicBorderlessDecoration::updateResizeBorders);
        connect(w, &KDecoration3::DecoratedWindow::resizeableChanged,
                this, &NordicBorderlessDecoration::updateResizeBorders);
        connect(w, &KDecoration3::DecoratedWindow::adjacentScreenEdgesChanged,
                this, &NordicBorderlessDecoration::updateResizeBorders);

        return true;
    }

    void paint(QPainter *painter, const QRectF &repaintArea) override
    {
        Q_UNUSED(painter);
        Q_UNUSED(repaintArea);
        // Intentionally empty: 0px visible titlebar & frame;
        // kwin4_effect_shapecorners draws rounded corners, sage/teal outlines, and shadows.
    }

private:
    void updateResizeBorders()
    {
        auto *w = window();
        if (!w || !w->isResizeable() || w->isMaximized()) {
            setResizeOnlyBorders(QMarginsF(0.0, 0.0, 0.0, 0.0));
            return;
        }

        constexpr qreal grip = 8.0;
        const Qt::Edges edges = w->adjacentScreenEdges();
        const qreal left = (w->isMaximizedHorizontally() || edges.testFlag(Qt::LeftEdge)) ? 0.0 : grip;
        const qreal right = (w->isMaximizedHorizontally() || edges.testFlag(Qt::RightEdge)) ? 0.0 : grip;
        const qreal top = (w->isMaximizedVertically() || edges.testFlag(Qt::TopEdge)) ? 0.0 : grip;
        const qreal bottom = (w->isMaximizedVertically() || edges.testFlag(Qt::BottomEdge)) ? 0.0 : grip;

        setResizeOnlyBorders(QMarginsF(left, top, right, bottom));
    }
};

K_PLUGIN_FACTORY_WITH_JSON(
    NordicBorderlessFactory,
    "metadata.json",
    registerPlugin<NordicBorderlessDecoration>();
)

#include "NordicBorderlessDecoration.moc"
