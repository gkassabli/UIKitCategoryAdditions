//
//  UIActionSheet+MKBlockAdditions.m
//  UIKitCategoryAdditions
//
//  Created by Mugunth on 21/03/11.
//  Copyright 2011 Steinlogic All rights reserved.
//

#import "UIActionSheet+MKBlockAdditions.h"

static NSMutableSet* sRetainerSet;
static dispatch_once_t onceToken;

@interface MKBlockAdditionsActionSheetDelegate : NSObject <UIActionSheetDelegate>
{
    DismissBlock _dismissBlock;
    CancelBlock _cancelBlock;
}

+ (instancetype)delegateWithDismissBlock:(DismissBlock)dismissBlock cancelBlock:(CancelBlock)cancelBlock;

@end

@implementation MKBlockAdditionsActionSheetDelegate

+ (instancetype)delegateWithDismissBlock:(DismissBlock)dismissBlock cancelBlock:(CancelBlock)cancelBlock
{
    MKBlockAdditionsActionSheetDelegate* delegate = [self new];
    delegate->_dismissBlock = dismissBlock;
    delegate->_cancelBlock = cancelBlock;
    
    dispatch_once(&onceToken, ^{
        sRetainerSet = [NSMutableSet new];
    });
    [sRetainerSet addObject:delegate];
    
    return delegate;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == [actionSheet cancelButtonIndex])
		_cancelBlock();
    else
        _dismissBlock(buttonIndex);
    [sRetainerSet removeObject:self];
}

@end


@interface MKBlockAdditionsPhotoPickerDelegate : NSObject <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    CancelBlock _cancelBlock;
    PhotoPickedBlock _photoPickedBlock;
    UIViewController *_presentVC;
}

+ (instancetype)delegateWithPhotoPickedBlock:(PhotoPickedBlock)photoPickedBlock cancelBlock:(CancelBlock)cancelBlock presentingController:(UIViewController*)presentingController;

@end

@implementation MKBlockAdditionsPhotoPickerDelegate

+ (instancetype)delegateWithPhotoPickedBlock:(PhotoPickedBlock)photoPickedBlock cancelBlock:(CancelBlock)cancelBlock presentingController:(UIViewController *)presentingController
{
    MKBlockAdditionsPhotoPickerDelegate* delegate = [self new];
    delegate->_photoPickedBlock = photoPickedBlock;
    delegate->_cancelBlock = cancelBlock;
    delegate->_presentVC = presentingController;
    
    dispatch_once(&onceToken, ^{
        sRetainerSet = [NSMutableSet new];
    });
    [sRetainerSet addObject:delegate];
    
    return delegate;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == [actionSheet cancelButtonIndex])
	{
		_cancelBlock();
        [sRetainerSet removeObject:self];
	}
    else
    {
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
            buttonIndex ++;
        if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
            buttonIndex ++;
        
        
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.allowsEditing = YES;
        
        if (buttonIndex == 1)
            picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        else if (buttonIndex == 2)
            picker.sourceType = UIImagePickerControllerSourceTypeCamera;;
        
        [_presentVC presentViewController:picker animated:YES completion:^(void){}];
    }
}

#pragma mark - UIImagePickerController

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	UIImage *editedImage = (UIImage*) [info valueForKey:UIImagePickerControllerEditedImage];
    if (!editedImage)
        editedImage = (UIImage*) [info valueForKey:UIImagePickerControllerOriginalImage];
    
    _photoPickedBlock(editedImage);
	[picker dismissViewControllerAnimated:YES completion:^(void){}];
    [sRetainerSet removeObject:self];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    // Dismiss the image selection and close the program
	[picker dismissViewControllerAnimated:YES completion:^(void){}];
    _cancelBlock();
    [sRetainerSet removeObject:self];
}

@end


@implementation UIActionSheet (MKBlockAdditions)

+ (void)actionSheetWithTitle:(NSString *)title message:(NSString *)message buttons:(NSArray *)buttonTitles showInView:(UIView *)view onDismiss:(DismissBlock)dismissed onCancel:(CancelBlock)cancelled
{
    [UIActionSheet actionSheetWithTitle:title message:message destructiveButtonTitle:nil buttons:buttonTitles showInView:view onDismiss:dismissed onCancel:cancelled];
}

+ (void)actionSheetWithTitle:(NSString *)title message:(NSString *)message destructiveButtonTitle:(NSString *)destructiveButtonTitle buttons:(NSArray *)buttonTitles showInView:(UIView *)view onDismiss:(DismissBlock)dismissed onCancel:(CancelBlock)cancelled
{
    MKBlockAdditionsActionSheetDelegate *actionSheetDelegate = [MKBlockAdditionsActionSheetDelegate delegateWithDismissBlock:dismissed cancelBlock:cancelled];
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:actionSheetDelegate cancelButtonTitle:nil destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:nil];
    
    for (NSString* thisButtonTitle in buttonTitles)
        [actionSheet addButtonWithTitle:thisButtonTitle];
    
    [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
    actionSheet.cancelButtonIndex = [buttonTitles count];
    
    if (destructiveButtonTitle)
        actionSheet.cancelButtonIndex++;
    
    if ([view isKindOfClass:[UITabBar class]])
        [actionSheet showFromTabBar:(UITabBar*)view];
    else if ([view isKindOfClass:[UIBarButtonItem class]])
        [actionSheet showFromBarButtonItem:(UIBarButtonItem*)view animated:YES];
    else if ([view isKindOfClass:[UIView class]])
        [actionSheet showInView:view];
}

+ (void)photoPickerWithTitle:(NSString *)title showInView:(UIView *)view presentVC:(UIViewController *)presentingController onPhotoPicked:(PhotoPickedBlock)photoPicked onCancel:(CancelBlock)cancelled
{
    MKBlockAdditionsPhotoPickerDelegate *photoPickerDelegate = [MKBlockAdditionsPhotoPickerDelegate delegateWithPhotoPickedBlock:photoPicked cancelBlock:cancelled presentingController:presentingController];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:photoPickerDelegate cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];

    int cancelButtonIndex = -1;
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
	{
		[actionSheet addButtonWithTitle:NSLocalizedString(@"Camera", @"")];
		cancelButtonIndex ++;
	}
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
	{
		[actionSheet addButtonWithTitle:NSLocalizedString(@"Photo library", @"")];
		cancelButtonIndex ++;
	}
    
	[actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
	cancelButtonIndex ++;
	
	actionSheet.cancelButtonIndex = cancelButtonIndex;		 

    if ([view isKindOfClass:[UITabBar class]])
        [actionSheet showFromTabBar:(UITabBar*)view];
    else if ([view isKindOfClass:[UIBarButtonItem class]])
        [actionSheet showFromBarButtonItem:(UIBarButtonItem*)view animated:YES];
    else if ([view isKindOfClass:[UIView class]])
        [actionSheet showInView:view];
}

@end
