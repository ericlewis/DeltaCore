//
//  ControllerView.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit

public class ControllerView: UIView, GameController
{
    //MARK: - Properties -
    /** Properties **/
    public var controllerSkin: ControllerSkinProtocol? {
        didSet {
            self.updateControllerSkin()
        }
    }
    
    public var controllerSkinTraits: ControllerSkin.Traits?
    {
        set { self.overrideTraits = newValue }
        get
        {
            if let traits = self.overrideTraits
            {
                return traits
            }
            
            guard let superview = self.superview else { return nil }
            
            let traits = ControllerSkin.Traits.defaults(for: superview)
            return traits
        }
    }
    
    public var controllerSkinSize: ControllerSkin.Size!
    {
        set { self.overrideSize = newValue }
        get
        {
            let size = self.overrideSize ?? UIScreen.main.defaultControllerSkinSize
            return size
        }
    }
    
    //MARK: - <GameControllerType>
    /// <GameControllerType>
    public var playerIndex: Int?
    public var inputTransformationHandler: ((GameController, Input) -> [Input])?
    public let _stateManager = GameControllerStateManager()
    
    //MARK: - Private Properties
    fileprivate let imageView = UIImageView(frame: CGRect.zero)
    fileprivate var transitionImageView: UIImageView? = nil
    fileprivate let controllerDebugView = ControllerDebugView()
    
    fileprivate var overrideTraits: ControllerSkin.Traits?
    fileprivate var overrideSize: ControllerSkin.Size?
    
    fileprivate var feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    fileprivate var _performedInitialLayout = false
    
    fileprivate var touchInputsMappingDictionary: [UITouch: Set<InputBox>] = [:]
    fileprivate var previousTouchInputs = Set<InputBox>()
    fileprivate var touchInputs: Set<InputBox> {
        return self.touchInputsMappingDictionary.values.reduce(Set<InputBox>(), { $0.union($1) })
    }
    
    public override var intrinsicContentSize: CGSize {
        return self.imageView.intrinsicContentSize
    }
    
    //MARK: - Initializers -
    /** Initializers **/
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        self.backgroundColor = UIColor.clear
        
        self.imageView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.imageView)
        
        self.controllerDebugView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
        self.controllerDebugView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(self.controllerDebugView)
        
        self.isMultipleTouchEnabled = true
        
        self.feedbackGenerator.prepare()
    }
    
    //MARK: - Overrides -
    /** Overrides **/
    
    //MARK: - UIView
    /// UIView
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self._performedInitialLayout = true
        
        self.updateControllerSkin()
    }
    
    //MARK: - UIResponder
    /// UIResponder
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = []
        }
        
        self.updateInputs(forTouches: touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.updateInputs(forTouches: touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = nil
        }
        
        self.updateInputs(forTouches: touches)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        return self.touchesEnded(touches, with: event)
    }
    
    //MARK: - <UITraitEnvironment>
    /// <UITraitEnvironment>
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.setNeedsLayout()
    }
}

//MARK: - Update Skins -
/// Update Skins
public extension ControllerView
{
    func beginAnimatingUpdateControllerSkin()
    {
        guard self.transitionImageView == nil else { return }
        
        let transitionImageView = UIImageView(image: self.imageView.image)
        transitionImageView.frame = self.imageView.frame
        transitionImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        transitionImageView.alpha = 1.0
        self.addSubview(transitionImageView)
        
        self.transitionImageView = transitionImageView
        
        self.imageView.alpha = 0.0
    }
    
    func updateControllerSkin()
    {
        guard self._performedInitialLayout else { return }
        
        if let isDebugModeEnabled = self.controllerSkin?.isDebugModeEnabled
        {
            self.controllerDebugView.isHidden = !isDebugModeEnabled
        }
        
        if let traits = self.controllerSkinTraits
        {
            self.controllerDebugView.items = self.controllerSkin?.items(for: traits)
            
            let image = self.controllerSkin?.image(for: traits, preferredSize: self.controllerSkinSize)
            self.imageView.image = image
        }        
        
        self.invalidateIntrinsicContentSize()
        
        if self.transitionImageView != nil
        {
            // Wrap in an animation closure to ensure it actually animates correctly
            // As of iOS 8.3, calling this within transition coordinator animation closure without wrapping
            // in this animation closure causes the change to be instantaneous
            UIView.animate(withDuration: 0.0) {
                self.imageView.alpha = 1.0
            }
        }
        else
        {
            self.imageView.alpha = 1.0
        }
        
        self.transitionImageView?.alpha = 0.0
    }
    
    func finishAnimatingUpdateControllerSkin()
    {
        if let transitionImageView = self.transitionImageView
        {
            transitionImageView.removeFromSuperview()
            self.transitionImageView = nil
        }
        
        self.imageView.alpha = 1.0
    }
}

//MARK: - Private Methods -
private extension ControllerView
{
    //MARK: - Activating/Deactivating Inputs
    func updateInputs(forTouches touches: Set<UITouch>)
    {
        guard let controllerSkin = self.controllerSkin else { return }
        
        // Don't add the touches if it has been removed in touchesEnded:/touchesCancelled:
        for touch in touches where self.touchInputsMappingDictionary[touch] != nil
        {
            var point = touch.location(in: self)
            point.x /= self.bounds.width
            point.y /= self.bounds.height
            
            if let traits = self.controllerSkinTraits
            {
                let inputs = controllerSkin.inputs(for: traits, point: point) ?? []
                let boxedInputs = inputs.lazy.flatMap { self.inputTransformationHandler?(self, $0) ?? [$0] }.map { InputBox(input: $0) }
                
                self.touchInputsMappingDictionary[touch] = Set(boxedInputs)
            }
        }
        
        let activatedInputs = self.touchInputs.subtracting(self.previousTouchInputs)
        for inputBox in activatedInputs
        {
            self.activate(inputBox.input)
        }
        
        let deactivatedInputs = self.previousTouchInputs.subtracting(self.touchInputs)
        for inputBox in deactivatedInputs
        {
            self.deactivate(inputBox.input)
        }
        
        if activatedInputs.count > 0
        {
            switch UIDevice.current.feedbackSupportLevel
            {
            case .feedbackGenerator: self.feedbackGenerator.impactOccurred()
            case .basic, .unsupported: UIDevice.current.vibrate()
            }
        }
        
        self.previousTouchInputs = self.touchInputs
    }
}