import SwiftUI

final class PickerCoordinator: NSObject, UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{
    func imagePickerController(
        _: UIImagePickerController,
        didFinishPickingMediaWithInfo _: [UIImagePickerController.InfoKey: Any]
    ) {
        print("foobar")
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    var selectedImage: UIImage? = nil
    var coordinator = PickerCoordinator()

    func makeUIViewController(
        context _: UIViewControllerRepresentableContext<ImagePickerView>
    )
        -> UIImagePickerController
    {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = coordinator
        return imagePicker
    }

    func updateUIViewController(
        _: UIImagePickerController,
        context _: UIViewControllerRepresentableContext<ImagePickerView>
    ) {}
}
