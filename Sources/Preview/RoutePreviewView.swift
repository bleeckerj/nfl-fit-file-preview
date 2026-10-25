import AppKit

final class RoutePreviewView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Route")
    private let detailsLabel = NSTextField(wrappingLabelWithString: "")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let fitButton = NSButton(title: "Fit Route", target: nil, action: nil)
    private let routeMap = RouteMapView()
    private let content = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        detailsLabel.font = .systemFont(ofSize: 12)
        detailsLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .center
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = .secondaryLabelColor
        fitButton.bezelStyle = .rounded
        fitButton.target = self
        fitButton.action = #selector(fitRoute)
        fitButton.setAccessibilityHelp("Show the entire recorded route")
        [titleLabel, detailsLabel, fitButton, content].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        [routeMap, messageLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: fitButton.leadingAnchor, constant: -16),
            fitButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            fitButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            detailsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            detailsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            content.topAnchor.constraint(equalTo: detailsLabel.bottomAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            routeMap.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            routeMap.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            routeMap.topAnchor.constraint(equalTo: content.topAnchor),
            routeMap.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            messageLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            messageLabel.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, multiplier: 0.8)
        ])
        showMessage("Select a FIT or GPX file to preview its route.")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func loading(filename: String) {
        titleLabel.stringValue = filename
        detailsLabel.stringValue = ""
        showMessage("Reading recorded route…")
    }

    func display(_ summary: RouteSummary) {
        titleLabel.stringValue = summary.filename
        detailsLabel.stringValue = SummaryFormatter.details(for: summary)
        guard summary.start != nil else {
            showMessage("No GPS route in this file.\nIndoor activities, settings, and summary files may contain no positions.")
            return
        }
        messageLabel.isHidden = true
        routeMap.isHidden = false
        fitButton.isHidden = false
        routeMap.display(summary)
    }

    func showError(_ error: Error) {
        detailsLabel.stringValue = ""
        showMessage(error.localizedDescription)
    }

    private func showMessage(_ message: String) {
        routeMap.reset()
        routeMap.isHidden = true
        fitButton.isHidden = true
        messageLabel.stringValue = message
        messageLabel.isHidden = false
    }

    @objc private func fitRoute() { routeMap.fitRoute() }
}
