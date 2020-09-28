//
//  HUDResponder.swift
//  Chrysan
//
//  Created by Harley-xk on 2020/9/25.
//  Copyright © 2020 Harley. All rights reserved.
//

import Foundation
import UIKit

/// HUD 风格的状态响应器
open class HUDResponder: StatusResponder {
    
    public init() {}
    
    /// 宿主 chrysan 视图
    public private(set) weak var host: Chrysan?
        
    /// 动画属性配置器
    public var animatorProvider: AnimatorProvider = CubicAnimatorProvider()
    
    /// 状态指示器视图配置器
    public var indicatorProvider: IndicatorProvider = HUDIndicatorProvider()

    /// 显示状态的视图
    public private(set) var statusView: HUDStatusView?
        
    // last running animator
    private weak var lastAnimator: UIViewPropertyAnimator?
    
    open func changeStatus(
        from current: Status,
        to new: Status,
        for host: Chrysan,
        finished: @escaping () -> ()
    ) {
        if new != .idle, statusView == nil {
            layoutStatusView(in: host)
        }
        
        // if the last status transforming is not finished, force to stop
        if let last = lastAnimator, last.isRunning {
            last.stopAnimation(true)
        }
        
        // 准备执行动画，设置相关视图的起始状态
        prepareAnimation(for: host, from: current, to: new)
        
        let animator = animatorProvider.makeAnimator()
        animator.addAnimations {
            self.runAnimation(for: host, from: current, to: new)
        }
        animator.addCompletion { [weak self] (position) in
            if position == .end {
                finished()
                self?.animationFinished(for: host, from: current, to: new)
            }
        }
        animator.startAnimation()
        lastAnimator = animator
    }
    
    // MARK: - Layout
    
    // 结束后将视图移除，如果在显示状态下修改了layout，该属性会被标记为 true，HUD 隐藏后会被移除
    private var removeViewOnFinish = false
    
    /// 布局属性，修改后从下一次显示 HUD 开始生效
    open var layout = HUDLayout() {
        didSet {
            // 修改布局属性，移除 HUD
            guard let view = statusView else { return }
            if host?.isActive == true {
                removeViewOnFinish = true
            } else {
                view.removeFromSuperview()
                statusView = nil
            }
        }
    }
    
    open func layoutStatusView(in chrysan: Chrysan) {
        
        host = chrysan
        
        let view = HUDStatusView(backgroundStyle: .dark, indicatorSize: layout.indicatorSize)
        view.indicatorProvider = indicatorProvider
        chrysan.addSubview(view)
        view.snp.removeConstraints()
        view.snp.makeConstraints {
            switch layout.position {
            case .center:
                $0.centerX.equalToSuperview().offset(layout.offset.x)
                $0.centerY.equalToSuperview().offset(layout.offset.y)
            case .top:
                $0.centerX.equalToSuperview().offset(layout.offset.x)
                $0.top.equalTo(chrysan.safeAreaLayoutGuide.snp.top).offset(layout.offset.y)
            case .bottom:
                $0.centerX.equalToSuperview().offset(layout.offset.x)
                $0.bottom.equalTo(chrysan.safeAreaLayoutGuide.snp.bottom).inset(layout.offset.y)
            }

            $0.left
                .greaterThanOrEqualTo(chrysan.safeAreaLayoutGuide.snp.left)
                .inset(layout.padding.left)
            $0.right
                .lessThanOrEqualTo(chrysan.safeAreaLayoutGuide.snp.right)
                .inset(layout.padding.right)
            $0.top
                .greaterThanOrEqualTo(chrysan.safeAreaLayoutGuide.snp.top)
                .inset(layout.padding.top)
            $0.bottom
                .lessThanOrEqualTo(chrysan.safeAreaLayoutGuide.snp.bottom)
                .inset(layout.padding.bottom)
            
            $0.size.greaterThanOrEqualTo(layout.indicatorSize)
        }
        statusView = view
    }

    // MARK: - Animations
    
    open func prepareAnimation(for chrysan: Chrysan, from: Status, to new: Status) {
        statusView?.prepreStatus(for: chrysan, from: from, to: new)
        if from == .idle {
            chrysan.backgroundColor = UIColor.black.withAlphaComponent(0)
            statusView?.alpha = 0
            statusView?.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        }
    }
    
    open func runAnimation(for chrysan: Chrysan, from: Status, to new: Status) {
        
        let isShowing = from == .idle && new != .idle
        let isHidding = from != .idle && new == .idle
        
        if isShowing {
            chrysan.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            statusView?.alpha = 1
            statusView?.transform = .identity
        } else if isHidding {
            chrysan.backgroundColor = UIColor.black.withAlphaComponent(0)
            statusView?.alpha = 0
            statusView?.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        }
        
        statusView?.updateStatus(for: chrysan, from: from, to: new)

    }
    
    open func animationFinished(for chrysan: Chrysan, from: Status, to new: Status) {
//        let isShowing = from == .idle && new != .idle
        let isHidden = from != .idle && new == .idle

        if isHidden && removeViewOnFinish {
            statusView?.removeFromSuperview()
            statusView = nil
            removeViewOnFinish = false
        }
        
        lastAnimator = nil
    }
}
