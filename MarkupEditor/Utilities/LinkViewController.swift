//
//  LinkViewController.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/1/22.
//

#if !os(macOS)

import UIKit

class LinkViewController: UIViewController {

    private var selectionState: SelectionState = MarkupEditor.selectionState
    private var initialHref: String?
    private var href: String!
    private var argHRef: String? { href.isEmpty ? nil : href.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var originalHRef: String?
    private var label: UILabel!
    private var linkView: UITextView!
    private var linkViewLabel: UILabel!
    private var buttonStack: UIStackView!
    private var removeButton: UIButton!
    private var removeButtonWidthConstraint: NSLayoutConstraint!
    private var spacer: UIView!
    private var spacerWidthConstraint: NSLayoutConstraint!
    private var cancelButton: UIButton!
    private var cancelButtonWidthConstraint: NSLayoutConstraint!
    private var saveButton: UIButton!
    private var saveButtonWidthConstraint: NSLayoutConstraint!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initializeContents()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func initializeContents() {
        view.backgroundColor = UIColor.systemBackground
        originalHRef = MarkupEditor.selectionState.href
        href = originalHRef ?? ""
        initializeLabel()
        initializeLinkView()
        initializeButtons()
        initializeLayout()
    }
    
    private func initializeLabel() {
        label = UILabel()
        label.text = MarkupEditor.selectionState.href == nil ? "Add a link:" : "Modify the link:"
        label.autoresizingMask = [.flexibleWidth]
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
    }
    
    private func initializeLinkView() {
        linkView = UITextView(frame: CGRect.zero)
        linkView.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
        linkView.text = originalHRef
        linkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        linkView.translatesAutoresizingMaskIntoConstraints = false
        linkView.keyboardType = .URL
        linkView.autocapitalizationType = .none
        linkView.autocorrectionType = .no
        linkView.delegate = self
        linkViewLabel = UILabel()
        linkViewLabel.text = "Enter link URL"
        linkViewLabel.font = .italicSystemFont(ofSize: (linkView.font?.pointSize)!)
        linkViewLabel.sizeToFit()
        linkView.addSubview(linkViewLabel)
        linkViewLabel.frame.origin = CGPoint(x: 5, y: (linkView.font?.pointSize)! / 2)
        linkViewLabel.textColor = .tertiaryLabel
        linkViewLabel.isHidden = !linkView.text.isEmpty
        // Show that the linkView has focus
        linkView.layer.borderWidth = 2
        linkView.layer.borderColor = view.tintColor.cgColor
        view.addSubview(linkView)
    }
    
    private func initializeButtons() {
        buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 4
        buttonStack.distribution = .fill
        view.addSubview(buttonStack)
        removeButton = UIButton(configuration: .borderedTinted(), primaryAction: nil)
        removeButton.preferredBehavioralStyle = UIBehavioralStyle.pad
        removeButton.configuration?.baseBackgroundColor = view.backgroundColor
        removeButton.configuration?.title = "Remove Link"
        // Avoid word wrapping
        removeButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        removeButton.layer.cornerRadius = 5
        removeButton.layer.borderWidth = 0.8
        removeButton.autoresizingMask = [.flexibleWidth]
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButtonWidthConstraint = removeButton.widthAnchor.constraint(equalToConstant: 110)
        removeButtonWidthConstraint.priority = .required
        removeButton.addTarget(self, action: #selector(remove), for: .touchUpInside)
        buttonStack.addArrangedSubview(removeButton)
        spacer = UIView()
        spacer.autoresizingMask = [.flexibleWidth]
        spacerWidthConstraint = spacer.widthAnchor.constraint(equalToConstant: 0)
        spacerWidthConstraint.priority = .defaultLow
        buttonStack.addArrangedSubview(spacer)
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
        // The cancelButton is always enabled, so it has an outline color.
        // Its background changes to indicate whether it's the default action,
        // which is something we change depending on whether we canSave().
        // It's hard to believe I have to do this in the year 2022, but I guess
        // so goes it when you actually want to be able to see a button rather than
        // just random text on the screen that might or might not be a button.
        cancelButton.layer.cornerRadius = 5
        cancelButton.layer.borderWidth = 0.8
        cancelButton.layer.borderColor = view.tintColor.cgColor
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
            spacerWidthConstraint,
            removeButtonWidthConstraint,
            removeButton.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.buttonHeight()),
            cancelButtonWidthConstraint,
            cancelButton.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.buttonHeight()),
            saveButtonWidthConstraint,
            saveButton.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.buttonHeight()),
            linkView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 8),
            linkView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -8),
            linkView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            linkView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -8),
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        setButtons()
        linkView.becomeFirstResponder()
    }
    
    /// Set the appearance of the saveButton and cancelButton.
    ///
    /// The cancelButton is always enabled, but will show filled with tintColor if the saveButton is disabled,
    /// indicating that the default action when enter is pressed is to cancel. When the saveButton is enabled,
    /// it shows with tintColor, and the cancelButton shows its border but is backgroundColor, indicating the
    /// default action when enter is pressed is to save. The removeButton is enabled or disabled but is never
    /// the default action so is not changed here.
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
    
    /// Set the button appearance based on what is enabled and disabled as the contents of linkView changes
    ///
    /// Note that setting the saveButton enabled/disabled invokes its configurationUpdateHandler which
    /// in turn executes setSaveCancel to configure both the saveButton and cancelButton.
    private func setButtons() {
        removeButton.isEnabled = MarkupEditor.selectionState.isInLink
        if removeButton.isEnabled {
            removeButton.layer.borderColor = view.tintColor.cgColor
        } else {
            removeButton.layer.borderColor = UIColor.clear.cgColor
        }
        saveButton.isEnabled = canSave()
    }
    
    private func canSave() -> Bool {
        if originalHRef == nil {
            guard MarkupEditor.selectionState.canLink, let href = argHRef else { return false }
            return href.isValidURL
        } else {
            if let href = argHRef {
                return href.isValidURL
            } else {
                return false
            }
        }
    }

    private func dismiss() {
        dismiss(animated: true) {
            MarkupEditor.selectedWebView?.becomeFirstResponder()
        }
    }
    
    /// Remove the link at the selection and dismiss
    @objc private func remove() {
        MarkupEditor.selectedWebView?.insertLink(nil)
        dismiss()
    }
    
    /// Save the link for the current selection (which may or may not be collapsed) and dismiss
    @objc private func save() {
        MarkupEditor.selectedWebView?.insertLink(argHRef)
        dismiss()
    }
    
    /// Cancel the link action and dismiss
    @objc private func cancel() {
        dismiss()
    }
    
    /// Return false to disable various menu items depending on selectionState
    @objc override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(showPluggableLinkPopover):
            return true     // Toggles off and on
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    /// Dismiss the popover if the hotkey to show it is used while it's already showing
    @objc func showPluggableLinkPopover() {
        dismiss()
    }
    
}

extension LinkViewController: UITextViewDelegate {
    
    /// Update href as the user types (note this never executes if shouldChangeTextIn returns false)
    func textViewDidChange(_ textView: UITextView) {
        href = textView.text
        linkViewLabel.isHidden = !textView.text.isEmpty
        setButtons()
    }
    
    /// Take the proper action when the user hits Enter, reject tabs, but otherwise accept the text
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            if canSave() {
                save()
            } else {
                cancel()
            }
            return false
        } else if text == "\t" {
            return false
        }
        return true
    }
    
}

#endif
