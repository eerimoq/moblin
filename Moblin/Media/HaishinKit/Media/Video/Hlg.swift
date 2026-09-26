import CoreImage

private let hlgKernels: (toLinear: CIColorKernel, toHlg: CIColorKernel)? = {
    guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
          let data = try? Data(contentsOf: url),
          let toLinear = try? CIColorKernel(functionName: "hlgToLinear", fromMetalLibraryData: data),
          let toHlg = try? CIColorKernel(functionName: "linearToHlg", fromMetalLibraryData: data)
    else {
        return nil
    }
    return (toLinear, toHlg)
}()

extension CIImage {
    func hlgToLinear() -> CIImage {
        hlgKernels?.toLinear.apply(extent: extent, arguments: [self]) ?? self
    }

    func linearToHlg() -> CIImage {
        hlgKernels?.toHlg.apply(extent: extent, arguments: [self]) ?? self
    }
}
