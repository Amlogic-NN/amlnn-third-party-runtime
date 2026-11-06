#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

#include "onnxruntime_cxx_api.h"
#include "core/providers/amlnn/amlnn_provider_factory.h"

namespace {

std::string ShapeString(const std::vector<int64_t>& shape) {
  std::string result = "[";
  for (size_t i = 0; i < shape.size(); ++i) {
    if (i != 0) result += ",";
    result += std::to_string(shape[i]);
  }
  return result + "]";
}

const char* TypeString(ONNXTensorElementDataType type) {
  switch (type) {
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
      return "float32";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
      return "float16";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16:
      return "bfloat16";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
      return "int8";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
      return "uint8";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16:
      return "int16";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16:
      return "uint16";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
      return "int32";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32:
      return "uint32";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
      return "int64";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64:
      return "uint64";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
      return "bool";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE:
      return "double";
    default:
      return "unsupported";
  }
}

size_t ElementSize(ONNXTensorElementDataType type) {
  switch (type) {
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32:
      return 4;
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE:
      return 8;
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16:
      return 2;
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
      return 1;
    default:
      throw std::runtime_error("unsupported tensor element type: " + std::to_string(type));
  }
}

size_t ByteSize(const std::vector<int64_t>& shape, ONNXTensorElementDataType type) {
  size_t count = 1;
  for (int64_t dim : shape) {
    // The benchmark/demo input generator uses 1 for symbolic dimensions.
    // Keep the same policy here so models with dynamic input shapes can be
    // exercised with the concrete input binaries supplied by the caller.
    dim = dim > 0 ? dim : 1;
    if (static_cast<uint64_t>(dim) > std::numeric_limits<size_t>::max() / count) {
      throw std::runtime_error("input tensor is too large");
    }
    count *= static_cast<size_t>(dim);
  }
  const size_t element_size = ElementSize(type);
  if (count > std::numeric_limits<size_t>::max() / element_size) {
    throw std::runtime_error("input tensor is too large");
  }
  return count * element_size;
}

std::vector<uint8_t> ReadFile(const std::string& path) {
  std::ifstream stream(path, std::ios::binary | std::ios::ate);
  if (!stream) throw std::runtime_error("cannot open input file: " + path);
  const std::streamsize size = stream.tellg();
  if (size < 0) throw std::runtime_error("cannot get input file size: " + path);
  stream.seekg(0, std::ios::beg);
  std::vector<uint8_t> data(static_cast<size_t>(size));
  if (size != 0 && !stream.read(reinterpret_cast<char*>(data.data()), size)) {
    throw std::runtime_error("cannot read input file: " + path);
  }
  return data;
}

void WriteFile(const std::string& path, const void* data, size_t size) {
  std::ofstream stream(path, std::ios::binary);
  if (!stream) throw std::runtime_error("cannot create output file: " + path);
  stream.write(static_cast<const char*>(data), static_cast<std::streamsize>(size));
  if (!stream) throw std::runtime_error("cannot write output file: " + path);
}

void WriteOutputMetadata(const std::string& path, const std::string& name,
                        const std::vector<int64_t>& shape,
                        ONNXTensorElementDataType type, size_t element_count) {
  std::ofstream stream(path);
  if (!stream) throw std::runtime_error("cannot create output metadata file: " + path);
  stream << "name=" << name << "\n";
  stream << "dtype=" << TypeString(type) << "\n";
  stream << "shape=" << ShapeString(shape) << "\n";
  stream << "elements=" << element_count << "\n";
  if (!stream) throw std::runtime_error("cannot write output metadata file: " + path);
}

void CheckStatus(OrtStatus* status) {
  if (status == nullptr) return;
  const OrtApi& api = Ort::GetApi();
  const std::string message = api.GetErrorMessage(status);
  api.ReleaseStatus(status);
  throw std::runtime_error(message);
}

template <typename T>
void PrintTop5Values(const T* data, size_t element_count) {
  struct Entry {
    size_t index;
    T value;
  };

  const size_t top_count = std::min<size_t>(5, element_count);
  std::vector<Entry> top;
  top.reserve(top_count);
  for (size_t i = 0; i < element_count; ++i) {
    auto position = top.begin();
    while (position != top.end() && !(data[i] > position->value)) {
      ++position;
    }
    if (position != top.end() || top.size() < top_count) {
      top.insert(position, Entry{i, data[i]});
      if (top.size() > top_count) top.pop_back();
    }
  }

  for (size_t rank = 0; rank < top.size(); ++rank) {
    std::cout << "  " << rank + 1 << ": index=" << top[rank].index
              << " value=" << static_cast<long double>(top[rank].value) << "\n";
  }
}

void PrintTop5(size_t output_index, const std::string& output_name,
               ONNXTensorElementDataType type, const void* data, size_t element_count) {
  std::cout << "Top 5 for output " << output_index << " (" << output_name << "):\n";
  switch (type) {
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
      PrintTop5Values(static_cast<const float*>(data), element_count);
      break;
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
      PrintTop5Values(static_cast<const int8_t*>(data), element_count);
      break;
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
      PrintTop5Values(static_cast<const uint8_t*>(data), element_count);
      break;
    default:
      std::cout << "  skipped: unsupported output type " << TypeString(type)
                << "(" << type << ")\n";
      break;
  }
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 3) {
    std::cerr << "Usage: " << argv[0]
              << " <model.onnx> <output_dir> [log_level] [input0.bin ...]\n"
              << "  Legacy form: <model.onnx> <model.adla> <output_dir> [log_level] [input0.bin ...]\n"
              << "  log_level: error, info, debug, 0, 1, or 2 (default: error)\n";
    return 2;
  }

  try {
    const std::string second_arg = argv[2];
    const bool legacy_adla_mode = second_arg.size() >= 5 &&
                                  second_arg.compare(second_arg.size() - 5, 5, ".adla") == 0;
    const int output_arg = legacy_adla_mode ? 3 : 2;
    const int first_optional_arg = output_arg + 1;
    if (legacy_adla_mode) {
      if (setenv("AMLNN_MODEL_PATH", argv[2], 1) != 0) {
        throw std::runtime_error("failed to set AMLNN_MODEL_PATH");
      }
    } else {
      unsetenv("AMLNN_MODEL_PATH");
      if (setenv("ORT_AMLNN_CONVERT_OUTPUT_DIR", argv[output_arg], 1) != 0) {
        throw std::runtime_error("failed to set ORT_AMLNN_CONVERT_OUTPUT_DIR");
      }
    }

    size_t input_arg = static_cast<size_t>(first_optional_arg);
    std::string log_level = "error";
    if (static_cast<size_t>(argc) > input_arg) {
      const std::string candidate = argv[input_arg];
      if (candidate == "error" || candidate == "info" || candidate == "debug" ||
          candidate == "0" || candidate == "1" || candidate == "2") {
        log_level = candidate;
        ++input_arg;
      } else if (candidate == "warning" || candidate == "warn" || candidate == "verbose" ||
                 candidate == "trace" || candidate == "fatal") {
        throw std::runtime_error("unsupported log level: " + candidate +
                                 "; use error, info, debug, 0, 1, or 2");
      }
    }
    if (setenv("ORT_AMLNN_LOG_LEVEL", log_level.c_str(), 1) != 0) {
      throw std::runtime_error("failed to set ORT_AMLNN_LOG_LEVEL");
    }

    std::cout << "Amlnn pipeline test configuration\n"
              << "  ONNX model: " << argv[1] << "\n"
              << "  Output directory: " << argv[output_arg] << "\n"
              << "  AMLNN log level: " << log_level << "\n";
    Ort::Env env(ORT_LOGGING_LEVEL_VERBOSE, "amlnn_pipeline_test");
    Ort::SessionOptions options;
    options.SetLogSeverityLevel(0);
    options.SetIntraOpNumThreads(1);
    options.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);
    options.AddConfigEntry("session.disable_cpu_ep_fallback", "1");
    CheckStatus(OrtSessionOptionsAppendExecutionProvider_Amlnn(options));

    std::cout << "Creating session\n";
    Ort::Session session(env, argv[1], options);
    Ort::AllocatorWithDefaultOptions allocator;
    const size_t input_count = session.GetInputCount();
    const size_t output_count = session.GetOutputCount();
    const size_t supplied_input_count = static_cast<size_t>(argc) - input_arg;
    std::cout << "Session created: inputs=" << input_count << " outputs=" << output_count
              << " supplied_inputs=" << supplied_input_count << "\n";
    if (supplied_input_count != 0 && supplied_input_count != input_count) {
      throw std::runtime_error("input file count does not match model input count");
    }

    std::vector<std::string> input_names;
    std::vector<const char*> input_name_ptrs;
    std::vector<std::vector<uint8_t>> input_data;
    std::vector<Ort::Value> input_values;
    input_names.reserve(input_count);
    input_name_ptrs.reserve(input_count);
    input_data.reserve(input_count);
    input_values.reserve(input_count);
    const auto memory_info = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);

    for (size_t i = 0; i < input_count; ++i) {
      auto name = session.GetInputNameAllocated(i, allocator);
      // TensorTypeAndShapeInfo returned by TypeInfo is non-owning. Keep the
      // TypeInfo owner alive while reading the tensor metadata.
      auto input_type_info = session.GetInputTypeInfo(i);
      auto tensor_info = input_type_info.GetTensorTypeAndShapeInfo();
      auto shape = tensor_info.GetShape();
      // Use a concrete extent of 1 for unresolved dimensions, matching the
      // bundled demo input-generation policy. This lets callers provide
      // concrete input binaries for models with symbolic input dimensions.
      std::transform(shape.begin(), shape.end(), shape.begin(), [](int64_t dim) {
        return dim > 0 ? dim : 1;
      });
      const auto type = tensor_info.GetElementType();
      const size_t expected_size = ByteSize(shape, type);
      input_names.emplace_back(name.get());
      if (supplied_input_count == 0) {
        input_data.emplace_back(expected_size, 0);
        std::cout << "Input " << i << " source=zeros\n";
      } else {
        input_data.emplace_back(ReadFile(argv[input_arg + i]));
        std::cout << "Input " << i << " source=" << argv[input_arg + i]
                  << " file_bytes=" << input_data.back().size() << "\n";
        if (input_data.back().size() != expected_size) {
          throw std::runtime_error("input " + std::to_string(i) + " size mismatch: expected " +
                                   std::to_string(expected_size) + ", got " +
                                   std::to_string(input_data.back().size()));
        }
      }
      input_values.emplace_back(Ort::Value::CreateTensor(
          memory_info, input_data.back().data(), input_data.back().size(),
          shape.data(), shape.size(), type));
      std::cout << "Input " << i << ": name=" << input_names.back()
                << " shape=" << ShapeString(shape) << " type=" << TypeString(type)
                << "(" << type << ") bytes=" << expected_size << "\n";
    }
    for (const auto& name : input_names) input_name_ptrs.push_back(name.c_str());

    std::vector<std::string> output_names;
    std::vector<const char*> output_name_ptrs;
    output_names.reserve(output_count);
    output_name_ptrs.reserve(output_count);
    for (size_t i = 0; i < output_count; ++i) {
      auto name = session.GetOutputNameAllocated(i, allocator);
      output_names.emplace_back(name.get());
      // See the input loop: keep TypeInfo alive for its non-owning view.
      const auto output_type_info = session.GetOutputTypeInfo(i);
      const auto output_info = output_type_info.GetTensorTypeAndShapeInfo();
      std::cout << "Expected output " << i << ": name=" << output_names.back()
                << " shape=" << ShapeString(output_info.GetShape())
                << " type=" << TypeString(output_info.GetElementType())
                << "(" << output_info.GetElementType() << ")\n";
    }
    for (const auto& name : output_names) output_name_ptrs.push_back(name.c_str());

    std::cout << "Running inference" << std::endl;
    auto outputs = session.Run(Ort::RunOptions{nullptr}, input_name_ptrs.data(),
                               input_values.data(), input_values.size(),
                               output_name_ptrs.data(), output_name_ptrs.size());
    for (size_t i = 0; i < outputs.size(); ++i) {
      const auto info = outputs[i].GetTensorTypeAndShapeInfo();
      const auto shape = info.GetShape();
      const size_t size = info.GetElementCount() * ElementSize(info.GetElementType());
      const std::string path = std::string(argv[output_arg]) + "/output_" + std::to_string(i) + ".bin";
      WriteFile(path, outputs[i].GetTensorRawData(), size);
      WriteOutputMetadata(std::string(argv[output_arg]) + "/output_" + std::to_string(i) + ".meta",
                          output_names[i], shape, info.GetElementType(), info.GetElementCount());
      std::cout << "Output " << i << ": name=" << output_names[i]
                << " shape=" << ShapeString(shape) << " type=" << TypeString(info.GetElementType())
                << "(" << info.GetElementType() << ") bytes=" << size << " file=" << path << "\n";
      PrintTop5(i, output_names[i], info.GetElementType(), outputs[i].GetTensorRawData(),
                info.GetElementCount());
    }
    std::cout << "AMLNN inference succeeded\n";
    return 0;
  } catch (const Ort::Exception& e) {
    std::cerr << "ONNX Runtime error: " << e.what() << "\n";
  } catch (const std::exception& e) {
    std::cerr << "Error: " << e.what() << "\n";
  }
  return 1;
}
