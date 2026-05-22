import SwiftUI
@preconcurrency import AVFoundation
import UIKit

/// Live-Barcode-Scanner via AVFoundation. Erkennt EAN-13/EAN-8/UPC-A/UPC-E.
/// Liefert beim ersten erfolgreichen Detect den Code-String via Callback und
/// dismisses sich selbst. Bietet ein Cozy-Reticle-Overlay + manuellen
/// Abbrechen-Button.
struct BarcodeScannerView: UIViewControllerRepresentable {
    /// Wird mit dem erkannten Code aufgerufen. Der Caller ist dafür
    /// verantwortlich, das Sheet zu schliessen.
    let onCode: (String) -> Void
    /// Wird aufgerufen, wenn der User auf "Abbrechen" tippt.
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC()
        vc.onCode = onCode
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerVC, context: Context) {}
}

/// UIKit-VC, der die `AVCaptureSession` managed und ein eigenes Cozy-Overlay
/// (Mascot, Reticle, Hinweis-Text, Abbrechen-Button) layoutet.
/// `@preconcurrency` auf der Delegate-Conformance, weil AVFoundation in Swift 6
/// die Methode nicht als isoliert markiert hat — wir leiten den UI-Update auf
/// MainActor zurück.
final class BarcodeScannerVC: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// Verhindert, dass beim ersten Detect mehrere Callbacks gefeuert werden
    /// (AVFoundation kann mehrere Frames hintereinander mit demselben Code liefern).
    private var hasDetected = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
        setupOverlay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasDetected = false
        // Snapshot fürs Background-Queue, damit Swift-6-Concurrency keine
        // Cross-actor-Warnung wirft.
        let s = session
        if !s.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                s.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            let s = session
            DispatchQueue.global(qos: .userInitiated).async {
                s.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    // MARK: - AVCaptureSession setup

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            showCameraError("Keine Kamera verfügbar.")
            return
        }
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            showCameraError("Kamera-Zugriff fehlgeschlagen.")
            return
        }
        guard session.canAddInput(input) else {
            showCameraError("Kamera-Input nicht möglich.")
            return
        }
        session.addInput(input)

        // Autofocus für Nah-Distanz konfigurieren. Default-Fokus versucht auch
        // Far-Objects zu treffen und „huntet" beim Barcode-Scan zwischen Nah
        // und Fern. `.near` Range Restriction beschleunigt das dramatisch —
        // Barcodes sind typisch 5–15 cm vor der Kamera.
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            device.unlockForConfiguration()
        } catch {
            Log.ui.error("Camera focus config failed: \(error.localizedDescription, privacy: .public)")
        }

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showCameraError("Kamera-Output nicht möglich.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Beschränken auf gängige Lebensmittel-Barcodes — schneller & weniger
        // False-Positives als bei "alles erlauben"
        output.metadataObjectTypes = [.ean13, .ean8, .upce]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.previewLayer = preview
    }

    // MARK: - Cozy Overlay

    private func setupOverlay() {
        // Halb-transparenter Dunkel-Layer mit "Loch" in der Mitte (Reticle-Area)
        let dim = UIView(frame: view.bounds)
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dim.isUserInteractionEnabled = false
        view.addSubview(dim)

        // Reticle (terra-farbene Eckwinkel)
        let reticleSize = CGSize(width: 280, height: 180)
        let reticle = UIView()
        reticle.translatesAutoresizingMaskIntoConstraints = false
        reticle.backgroundColor = .clear
        reticle.layer.borderColor = UIColor(red: 217/255, green: 119/255, blue: 87/255, alpha: 1).cgColor
        reticle.layer.borderWidth = 2
        reticle.layer.cornerRadius = 18
        view.addSubview(reticle)
        NSLayoutConstraint.activate([
            reticle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticle.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            reticle.widthAnchor.constraint(equalToConstant: reticleSize.width),
            reticle.heightAnchor.constraint(equalToConstant: reticleSize.height)
        ])

        // Hinweis-Text über dem Reticle
        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.text = "Barcode im Rahmen platzieren"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.textAlignment = .center
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: reticle.topAnchor, constant: -16)
        ])

        // Abbrechen-Button — iOS 15+ Configuration API
        var config = UIButton.Configuration.plain()
        var titleAttrs = AttributeContainer()
        titleAttrs.font = .systemFont(ofSize: 16, weight: .semibold)
        titleAttrs.foregroundColor = UIColor.white
        config.attributedTitle = AttributedString("Abbrechen", attributes: titleAttrs)
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        let cancel = UIButton(configuration: config)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        cancel.layer.cornerRadius = 22
        cancel.layer.masksToBounds = true
        cancel.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        view.addSubview(cancel)
        NSLayoutConstraint.activate([
            cancel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    @objc private func handleCancel() {
        onCancel?()
    }

    private func showCameraError(_ msg: String) {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = msg
        label.textColor = .white
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Detection

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDetected else { return }
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue, !code.isEmpty else { return }
        hasDetected = true

        // Haptic-Feedback bei erfolgreichem Scan
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        onCode?(code)
    }
}
