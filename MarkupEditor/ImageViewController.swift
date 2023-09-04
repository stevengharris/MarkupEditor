//
//  ImageViewController.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/2/22.
//

import UIKit

class ImageViewController: UIViewController {

    private var selectionState: SelectionState = MarkupEditor.selectionState
    private var initialHref: String?
    private var src: String!
    private var argSrc: String? { argForEntry(src) }
    private var alt: String!
    private var argAlt: String? { argForEntry(alt) }
    private var originalSrc: String?
    private var originalAlt: String?
    private var savedSrc: String?
    private var savedAlt: String?
    private var label: UILabel!
    private var textStack: UIStackView!
    private var srcView: UITextView!
    private var srcViewLabel: UILabel!
    private var altView: UITextView!
    private var altViewLabel: UILabel!
    private var buttonStack: UIStackView!
    private var selectButton: UIButton!
    private var selectButtonWidthConstraint: NSLayoutConstraint!
    private var cancelButton: UIButton!
    private var cancelButtonWidthConstraint: NSLayoutConstraint!
    private var saveButtonWidthConstraint: NSLayoutConstraint!
    private var saveButton: UIButton!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initializeContents()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func initializeContents() {
        view.backgroundColor = UIColor.systemBackground
        originalSrc = MarkupEditor.selectionState.src
        src = originalSrc ?? ""
        savedSrc = originalSrc
        originalAlt = MarkupEditor.selectionState.alt
        alt = originalAlt ?? ""
        savedAlt = originalAlt
        initializeLabel()
        initializeTextViews()
        initializeButtons()
        initializeLayout()
    }
    
    private func initializeLabel() {
        label = UILabel()
        label.text = originalSrc == nil ? "Insert an image:" : "Modify the image:"
        label.autoresizingMask = [.flexibleWidth]
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
    }
    
    private func initializeTextViews() {
        textStack = UIStackView()
        textStack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.distribution = .fill
        view.addSubview(textStack)
        srcView = UITextView(frame: CGRect.zero)
        srcView.layer.borderWidth = 2
        srcView.layer.borderColor = UIColor.lightGray.cgColor
        srcView.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
        srcView.text = originalSrc
        srcView.keyboardType = .URL
        srcView.autocapitalizationType = .none
        srcView.autocorrectionType = .no
        srcView.delegate = self
        srcViewLabel = UILabel()
        srcViewLabel.text = "Enter image URL"
        srcViewLabel.font = .italicSystemFont(ofSize: (srcView.font?.pointSize)!)
        srcViewLabel.sizeToFit()
        srcView.addSubview(srcViewLabel)
        srcViewLabel.frame.origin = CGPoint(x: 5, y: (srcView.font?.pointSize)! / 2)
        srcViewLabel.textColor = .tertiaryLabel
        srcViewLabel.isHidden = !srcView.text.isEmpty
        textStack.addArrangedSubview(srcView)
        altView = UITextView(frame: CGRect.zero)
        altView.layer.borderWidth = 2
        altView.layer.borderColor = UIColor.lightGray.cgColor
        altView.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
        altView.text = originalAlt
        altView.keyboardType = .default
        altView.delegate = self
        altViewLabel = UILabel()
        altViewLabel.text = "Enter description"
        altViewLabel.font = .italicSystemFont(ofSize: (altView.font?.pointSize)!)
        altViewLabel.sizeToFit()
        altView.addSubview(altViewLabel)
        altViewLabel.frame.origin = CGPoint(x: 5, y: (altView.font?.pointSize)! / 2)
        altViewLabel.textColor = .tertiaryLabel
        altViewLabel.isHidden = !srcView.text.isEmpty
        textStack.addArrangedSubview(altView)
    }
    
    private func initializeButtons() {
        buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 4
        buttonStack.distribution = .fill
        view.addSubview(buttonStack)
        if MarkupEditor.allowLocalImages {
            selectButton = UIButton(configuration: .borderedTinted(), primaryAction: nil)
            selectButton.preferredBehavioralStyle = UIBehavioralStyle.pad
            selectButton.configuration?.baseBackgroundColor = view.backgroundColor
            selectButton.configuration?.title = "Select..."
            // Avoid word wrapping
            selectButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            selectButton.layer.cornerRadius = 5
            selectButton.layer.borderWidth = 0.8
            selectButton.autoresizingMask = [.flexibleWidth]
            selectButton.translatesAutoresizingMaskIntoConstraints = false
            selectButtonWidthConstraint = selectButton.widthAnchor.constraint(equalToConstant: 110)
            selectButtonWidthConstraint.priority = .required
            selectButton.addTarget(self, action: #selector(selectImage), for: .touchUpInside)
            buttonStack.addArrangedSubview(selectButton)
        }
        cancelButton = UIButton(configuration: .borderedProminent(), primaryAction: nil)
        cancelButton.preferredBehavioralStyle = UIBehavioralStyle.pad
        cancelButton.configuration?.title = "Cancel"
        // Avoid word wrapping
        cancelButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        cancelButton.autoresizingMask = [.flexibleWidth]
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: 70)
        cancelButtonWidthConstraint.priority = .defaultHigh
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        buttonStack.addArrangedSubview(cancelButton)
        saveButton = UIButton(configuration: .borderedProminent(), primaryAction: nil)
        saveButton.preferredBehavioralStyle = UIBehavioralStyle.pad
        saveButton.configuration?.title = "OK"
        saveButton.autoresizingMask = [.flexibleWidth]
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButtonWidthConstraint = saveButton.widthAnchor.constraint(equalTo: cancelButton.widthAnchor, multiplier: 1)
        saveButtonWidthConstraint.priority = .defaultHigh
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)
        buttonStack.addArrangedSubview(saveButton)
        saveButton.configurationUpdateHandler = setSaveCancel(_:)
        setButtons()
        // The cancelButton is always enabled, so it has an outline color.
        // It's background changes to indicate whether it's the default action,
        // which is something we change depending on whether we canSave().
        // It's hard to believe I have to do this in the year 2022, but I guess
        // so goes it when you actually want to be able to see a button rather than
        // just random text on the screen that might or might not be a button.
        cancelButton.layer.cornerRadius = 5
        cancelButton.layer.borderWidth = 0.8
        cancelButton.layer.borderColor = view.tintColor.cgColor
    }
    
    private func initializeLayout() {
        NSLayoutConstraint.activate([
            label.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 8),
            label.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            buttonStack.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 8),
            buttonStack.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -8),
            buttonStack.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.buttonHeight()),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            cancelButtonWidthConstraint,
            cancelButton.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.buttonHeight()),
            saveButtonWidthConstraint,
            saveButton.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.buttonHeight()),
            textStack.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 8),
            textStack.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -8),
            textStack.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            textStack.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -8),
            altView.heightAnchor.constraint(equalTo: srcView.heightAnchor, multiplier: 1, constant: 0),
        ])
        if MarkupEditor.allowLocalImages {
            NSLayoutConstraint.activate([
                selectButtonWidthConstraint,
                selectButton.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.buttonHeight()),
            ])
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setButtons()
        setTextViews()
        srcView.becomeFirstResponder()
    }
    
    /// Set the appearance of the saveButton and cancelButton.
    ///
    /// The cancelButton is always enabled, but will show filled with tintColor if the saveButton is disabled,
    /// indicating that the default action when enter is pressed is to cancel. When the saveButton is enabled,
    /// it shows with tintColor, and the cancelButton shows its border but is backgroundColor, indicating the
    /// default action when enter is pressed is to save.
    private func setSaveCancel(_ button: UIButton) {
        if saveButton.isEnabled {
            saveButton.configuration?.baseBackgroundColor = view.tintColor
            saveButton.configuration?.baseForegroundColor = view.backgroundColor
            cancelButton.configuration?.baseBackgroundColor = view.backgroundColor
            cancelButton.configuration?.baseForegroundColor = view.tintColor
        } else {
            saveButton.configuration?.baseBackgroundColor = view.backgroundColor
            saveButton.configuration?.baseForegroundColor = view.tintColor
            cancelButton.configuration?.baseBackgroundColor = view.tintColor
            cancelButton.configuration?.baseForegroundColor = view.backgroundColor
        }
    }
    
    /// Set the button appearance based on what is enabled and disabled as the contents of srcView changes
    ///
    /// Note that setting the saveButton enabled/disabled invokes its configurationUpdateHandler which
    /// in turn executes setSaveCancel to configure both the saveButton and cancelButton.
    private func setButtons() {
        if let selectButton = selectButton {
            selectButton.isEnabled = MarkupEditor.selectionState.canInsert
            if selectButton.isEnabled {
                selectButton.layer.borderColor = view.tintColor.cgColor
            } else {
                selectButton.layer.borderColor = UIColor.clear.cgColor
            }
        }
        saveButton.isEnabled = canSave()
    }
    
    private func setTextViews() {
        if srcView.isFirstResponder {
            srcView.layer.borderColor = view.tintColor.cgColor
            altView.layer.borderColor = UIColor.lightGray.cgColor
        } else if altView.isFirstResponder {
            srcView.layer.borderColor = UIColor.lightGray.cgColor
            altView.layer.borderColor = view.tintColor.cgColor
        } else {
            srcView.layer.borderColor = UIColor.lightGray.cgColor
            altView.layer.borderColor = UIColor.lightGray.cgColor
        }
    }

    private func argForEntry(_ entry: String) -> String? {
        let arg = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        return arg.isEmpty ? nil : arg
    }
    
    /// Save the image, but if argSrc is nil, then we need to use modifyImage to delete the image
    private func saveImage(_ handler: (()->Void)? = nil) {
        if let argSrc = argSrc {
            MarkupEditor.selectedWebView?.insertImage(src: argSrc, alt: argAlt, handler: handler)
        } else {
            MarkupEditor.selectedWebView?.modifyImage(src: argSrc, alt: argAlt, handler: handler)
        }
        savedSrc = src
        savedAlt = alt
    }
    
    private func canSave() -> Bool {
        guard MarkupEditor.selectionState.canInsert, argSrc != nil else { return false }
        return true
    }
    
    @objc private func selectImage() {
        let controller =  UIDocumentPickerViewController(forOpeningContentTypes: MarkupEditor.supportedImageTypes)
        controller.allowsMultipleSelection = false
        controller.delegate = self
        present(controller, animated: true)
    }
    
    private func dismiss() {
        dismiss(animated: true) {
            MarkupEditor.selectedWebView?.becomeFirstResponder()
        }
    }

    /// Save the image for the current selection if needed and dismiss
    @objc private func save() {
        if canSave() && (src != savedSrc || alt != savedAlt) {
            saveImage {
                self.dismiss()
            }
        } else {
            dismiss()
        }
    }
    
    /// Cancel the insert image action and dismiss
    @objc private func cancel() {
        if savedImageHasChanged() {
            // We saved something to the document that we want to abandon
            src = originalSrc ?? ""
            alt = originalAlt ?? ""
            saveImage {
                self.dismiss()
            }
        } else {
            // Use endModalInput because insertImage was never called to restore selection
            MarkupEditor.selectedWebView?.endModalInput {
                self.dismiss()
            }
        }
    }
    
    private func currentImageHasChanged() -> Bool {
        savedSrc == nil || (savedSrc != nil && savedSrc != src) || savedAlt != alt
    }
    
    private func savedImageHasChanged() -> Bool {
        (savedSrc != nil && savedSrc != originalSrc) || (savedAlt != nil && savedAlt != originalAlt)
    }
    
}

extension ImageViewController: UITextViewDelegate {
    
    /// Update src as the user types (note this never executes if shouldChangeTextIn returns false)
    func textViewDidChange(_ textView: UITextView) {
        if textView == srcView {
            src = textView.text
            srcViewLabel.isHidden = !textView.text.isEmpty
            setButtons()
        } else if textView == altView {
            alt = textView.text
            altViewLabel.isHidden = !textView.text.isEmpty
            setButtons()
        }
    }
    
    /// Take the proper action when the user hits Enter, tabs alternate between the two text views
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            if canSave() {
                save()
            } else {
                cancel()
            }
            return false
        } else if text == "\t" {
            if textView == srcView {
                altView.becomeFirstResponder()
                let selectedRange = altView.selectedTextRange
                if selectedRange == nil {
                    altView.selectedTextRange = altView.textRange(from: altView.endOfDocument, to: altView.endOfDocument)
                }
            } else if textView == altView {
                srcView.becomeFirstResponder()
                let selectedRange = srcView.selectedTextRange
                if selectedRange == nil {
                    srcView.selectedTextRange = srcView.textRange(from: srcView.endOfDocument, to: srcView.endOfDocument)
                }
            }
            if currentImageHasChanged() {
                saveImage()
            }
            return false
        }
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        setTextViews()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        setTextViews()
    }
    
}

extension ImageViewController: UIDocumentPickerDelegate {
    
    /// Use the standard UIDocumentPickerViewController to choose a local image
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        MarkupEditor.selectedWebView?.insertLocalImage(url: url) { cachedImageUrl in
            let relativeSrc = cachedImageUrl.relativeString
            self.src = relativeSrc
            self.savedSrc = relativeSrc
            self.srcView.text = relativeSrc
            self.srcViewLabel.isHidden = !self.srcView.text.isEmpty
            self.setButtons()
            self.setTextViews()
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        MarkupEditor.selectImage.value = false
        controller.dismiss(animated: true, completion: nil)
    }
    
}
