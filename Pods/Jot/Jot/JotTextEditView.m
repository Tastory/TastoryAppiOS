//
//  JotTextEditView.m
//  jot
//
//  Created by Laura Skelton on 4/30/15.
//
//

#import "JotLabel.h"
#import "JotTextEditView.h"
#import <Masonry/Masonry.h>

@interface JotTextEditView () <UITextViewDelegate>

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIView *textBackground;
@property (nonatomic, strong) UIView *textContainer;
@property (nonatomic, strong) CAGradientLayer *gradientMask;
@property (nonatomic, strong) CAGradientLayer *topGradient;
@property (nonatomic, strong) CAGradientLayer *bottomGradient;

@end

@implementation JotTextEditView

- (instancetype)init
{
    if ((self = [super init])) {
        
        self.backgroundColor = [UIColor clearColor];
      
        // Initialize state parameters
        _font = [UIFont systemFontOfSize:40.f];
        _fontSize = 40.f;
        _textColor = [UIColor whiteColor];
        _backingColor = [UIColor colorWithWhite:1.0f alpha:0.0f];
        _textEditingInsets = UIEdgeInsetsMake(0.f, 0.f, 0.f, 0.f);
      
        _textContainer = [UIView new];
        self.textContainer.layer.masksToBounds = YES;
        [self addSubview:self.textContainer];
        [self.textContainer mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.and.left.and.right.equalTo(self);
            make.bottom.equalTo(self).offset(0.f);
        }];
        
        _textView = [UITextView new];
        self.textView.keyboardType = UIKeyboardTypeDefault;
        self.textView.keyboardAppearance = UIKeyboardAppearanceDark;
        self.textView.returnKeyType = UIReturnKeyDefault;
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        self.textView.autocorrectionType = UITextAutocorrectionTypeDefault;
        self.textView.spellCheckingType = UITextSpellCheckingTypeNo;
      
        self.textView.backgroundColor = [UIColor clearColor];
        self.textView.text = self.textString;
        self.textView.textColor = self.textColor;
        self.textView.showsVerticalScrollIndicator = NO;
        self.textView.showsHorizontalScrollIndicator = NO;
      
        self.textView.textContainer.lineFragmentPadding = 0;
        [self.textView setTextContainerInset:UIEdgeInsetsZero];
      
        self.textView.delegate = self;
      
        [self.textContainer addSubview:self.textView];
        [self.textView mas_makeConstraints:^(MASConstraintMaker *make) {
          make.edges.equalTo(self.textContainer).insets(_textEditingInsets);
        }];
      
        _textBackground = [UIView new];
        self.textBackground.backgroundColor = self.backingColor;
        self.textBackground.layer.cornerRadius = self.fontSize * bgCornerRadiusAsFontFraction;
        self.textBackground.clipsToBounds = YES;
        [self.textContainer addSubview:self.textBackground];
        [self.textContainer insertSubview:self.textBackground belowSubview:self.textView];
      
        self.textContainer.hidden = YES;
        self.userInteractionEnabled = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(
            handleKeyboardWillChangeFrameNotification:) name:UIKeyboardWillChangeFrameNotification
            object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    self.textView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:
        UIKeyboardWillChangeFrameNotification object:nil];
}

#pragma mark - Notifications

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)aNotification
{
    CGRect keyboardRectEnd = [aNotification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [aNotification.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];

    if (self.adjustContentInsetsOnKeyboardFrameChange) {
        CGRect textViewRect = [self.textContainer convertRect:self.textView.frame toView:self.window];
        if (CGRectIntersectsRect(keyboardRectEnd, textViewRect)) {
            CGRect intersectionRect = CGRectIntersection(keyboardRectEnd, textViewRect);

            UIEdgeInsets insets = self.textView.contentInset;
            insets.bottom = intersectionRect.size.height;
            self.textView.contentInset = insets;

            insets = self.textView.scrollIndicatorInsets;
            insets.bottom = intersectionRect.size.height;
            self.textView.scrollIndicatorInsets = insets;
        } else {
            UIEdgeInsets insets = self.textView.contentInset;
            insets.bottom = 0.0f;
            self.textView.contentInset = insets;

            insets = self.textView.scrollIndicatorInsets;
            insets.bottom = 0.0f;
            self.textView.scrollIndicatorInsets = insets;
        }
    } else {
        [self.textContainer.layer removeAllAnimations];

        if ([self keyboardWillDisappear:keyboardRectEnd]) {
            [self mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.size.mas_equalTo(self.superview);
                make.center.equalTo(self.superview);
            }];
            
        } else {
            CGFloat screenSpaceRemaining = CGRectGetHeight([UIScreen mainScreen].applicationFrame) - CGRectGetHeight(keyboardRectEnd);
            [self mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(self.superview);
                make.left.equalTo(self.superview);
                make.right.equalTo(self.superview);
                make.height.equalTo(@(screenSpaceRemaining));
            }];
        }
        
        [UIView animateWithDuration:duration delay:0.f options:UIViewAnimationOptionBeginFromCurrentState
            animations:^{
                [self.textContainer layoutIfNeeded];
            } completion:nil];
	}
}

- (BOOL)keyboardWillDisappear:(CGRect)keyboardRectEnd {
    return keyboardRectEnd.origin.y >= [UIScreen mainScreen].applicationFrame.size.height;
}

#pragma mark - Properties

- (void)setTextString:(NSString *)textString
{
    if (![_textString isEqualToString:textString]) {
        _textString = textString;
        self.textView.text = textString;
        [self.textView setContentOffset:CGPointZero animated:NO];
        [self textViewDidChange:self.textView];
    }
}

- (void)setTextEditingInsets:(UIEdgeInsets)textEditingInsets
{
    if (!UIEdgeInsetsEqualToEdgeInsets(_textEditingInsets, textEditingInsets)) {
        _textEditingInsets = textEditingInsets;
      
        [self.textView mas_updateConstraints:^(MASConstraintMaker *make) {
          make.edges.equalTo(self.textContainer).insets(textEditingInsets);
        }];

        [self.textView layoutIfNeeded];
        [self.textView setContentOffset:CGPointZero animated:NO];
        [self textViewDidChange:self.textView];
    }
}

- (void)setFont:(UIFont *)font
{
    if (_font != font) {
        _font = font;
        self.textView.font = [font fontWithSize:_fontSize];
        [self textViewDidChange:self.textView];
    }
}

- (void)setFontSize:(CGFloat)fontSize
{
    if (_fontSize != fontSize) {
        _fontSize = fontSize;
        self.textView.font = [_font fontWithSize:fontSize];
        [self textViewDidChange:self.textView];
    }
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
    if (_textAlignment != textAlignment) {
        _textAlignment = textAlignment;
        self.textView.textAlignment = textAlignment;
        [self textViewDidChange:self.textView];
    }
}

- (void)setTextColor:(UIColor *)textColor
{
    if (_textColor != textColor) {
        _textColor = textColor;
        self.textView.textColor = textColor;
    }
}

- (void)setClipBoundsToEditingInsets:(BOOL)clipBoundsToEditingInsets
{
    if (_clipBoundsToEditingInsets != clipBoundsToEditingInsets) {
        _clipBoundsToEditingInsets = clipBoundsToEditingInsets;
        _textView.clipsToBounds = clipBoundsToEditingInsets;
        [self setupGradientMask];
    }
}

- (void)setIsEditing:(BOOL)isEditing
{
    if (_isEditing != isEditing) {
        _isEditing = isEditing;
        self.textContainer.hidden = !isEditing;
        self.userInteractionEnabled = isEditing;
        if (isEditing) {
            self.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.5f];
            [self.textView becomeFirstResponder];
        } else {
            self.backgroundColor = [UIColor clearColor];
            _textString = self.textView.text;
            [self.textView resignFirstResponder];
            if ([self.delegate respondsToSelector:@selector(jotTextEditViewFinishedEditingWithNewTextString:)]) {
                [self.delegate jotTextEditViewFinishedEditingWithNewTextString:_textString];
            }
        }
    }
}


- (void)setBackingColor:(UIColor *)backingColor
{
    if (_backingColor != backingColor) {
        _backingColor = backingColor;
        self.textBackground.backgroundColor = backingColor;
    }
}


#pragma mark - Gradient Mask

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self setupGradientMask];
}

- (void)setupGradientMask
{
    if (!self.clipBoundsToEditingInsets) {
        self.textContainer.layer.mask = self.gradientMask;
        
        CGFloat percentTopOffset = self.textEditingInsets.top / CGRectGetHeight(self.textContainer.bounds);
        CGFloat percentBottomOffset = self.textEditingInsets.bottom / CGRectGetHeight(self.textContainer.bounds);
        
        self.gradientMask.locations = @[ @(0.f * percentTopOffset),
                                         @(0.8f * percentTopOffset),
                                         @(0.9f * percentTopOffset),
                                         @(1.f * percentTopOffset),
                                         @(1.f - (1.f * percentBottomOffset)),
                                         @(1.f - (0.9f * percentBottomOffset)),
                                         @(1.f - (0.8f * percentBottomOffset)),
                                         @(1.f - (0.f * percentBottomOffset)) ];
        
        self.gradientMask.frame = CGRectMake(0.f,
                                             0.f,
                                             CGRectGetWidth(self.textContainer.bounds),
                                             CGRectGetHeight(self.textContainer.bounds));
    } else {
        self.textContainer.layer.mask = nil;
    }
}

- (CAGradientLayer *)gradientMask
{
    if (!_gradientMask) {
        _gradientMask = [CAGradientLayer layer];
        _gradientMask.colors = @[ (id)[UIColor colorWithWhite:1.f alpha:0.f].CGColor,
                                  (id)[UIColor colorWithWhite:1.f alpha:0.4f].CGColor,
                                  (id)[UIColor colorWithWhite:1.f alpha:0.7f].CGColor,
                                  (id)[UIColor colorWithWhite:1.f alpha:1.f].CGColor,
                                  (id)[UIColor colorWithWhite:1.f alpha:1.f].CGColor,
                                  (id)[UIColor colorWithWhite:1.f alpha:0.7f].CGColor,
                                  (id)[UIColor colorWithWhite:1.f alpha:0.4f].CGColor,
                                  (id)[UIColor colorWithWhite:1.f alpha:0.f].CGColor
                                  ];
    }
    
    return _gradientMask;
}

#pragma mark - Text Editing

- (void)textViewDidChange:(UITextView *)textView
{
  if (textView.text.length <= 0) {
    self.textBackground.frame = CGRectZero;
    return;
  }
  
  CGRect usedRect = [textView.layoutManager usedRectForTextContainer:textView.textContainer];
  CGFloat height = MIN(usedRect.size.height, self.textView.bounds.size.height);
  CGFloat widthPadding = bgPadWidthAsFontFraction * self.fontSize;
  CGFloat heightPadding = bgPadHeightAsFontFraction * self.fontSize;
  
  CGRect bgRect = CGRectMake(self.textView.frame.origin.x + usedRect.origin.x - widthPadding,
                             self.textView.frame.origin.y + usedRect.origin.y - heightPadding,
                             usedRect.size.width + 2*widthPadding, height + 2*heightPadding);
  
  self.textBackground.frame = bgRect;
  self.textBackground.layer.cornerRadius = self.fontSize * bgCornerRadiusAsFontFraction;
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  // Let next line see the day of light!
//    if ([text isEqualToString: @"\n"]) {
//        self.isEditing = NO;
//        return NO;
//    }
  
    BOOL result = YES;
    NSUInteger actualTextLength = (textView.text.length - range.length);
    if ((actualTextLength + text.length) > 300) {
        result = NO;
    }
    if (!result) {
        if (actualTextLength < 300) {
            NSString *newText = [self cutText:text toLength:(300 - actualTextLength)];
            if (nil != newText) {
                UITextRange *textRange = textView.selectedTextRange;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [textView.inputDelegate textWillChange:textView];
                    [textView replaceRange:textRange withText:newText];
                    [textView.inputDelegate textDidChange:textView];
                  
                  
                });
            }
        }
    }
  
    return result;
}

- (NSString *)cutText:(NSString *)aText toLength:(NSUInteger)aLength
{
    NSRange range;
    NSUInteger textLength = aLength;
    do {
        range = [aText rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, textLength)];
    }
    while ((range.length > aLength) && (--textLength > 0));

    NSString *result = nil;
    if ((range.length > 0) && (range.length <= aLength)) {
        result = [aText substringWithRange:range];
    }
    return result;
}

@end
