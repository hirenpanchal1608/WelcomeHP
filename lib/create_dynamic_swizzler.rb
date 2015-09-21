#!/usr/bin/env ruby

require "json"
require 'zlib'
require 'set'
require_relative "errors_reporter"

if ARGV.length != 2
  STDERR.puts "Usage:\n$0: <input_json> <output_chunks_path>"
  exit 1
end

def wrapping(scope) #{{{
  producer_signature = scope[:producer_signature]
  r_k  = scope[:return_object][:kind]
  r  = scope[:return_object][:type]
  args = scope[:args] || []
  arg_list  = args.inject("") { |memo, o|
    "#{memo}, #{o[:name]}" 
  } 
  arg_names  = args.each_with_index.inject("") { |memo, (o, index)| 
    if o[:kind] == "Record"
      value = "recordPointer"
      dereferncingPrefix = "*(#{o[:type]}*)"
    else
      value = o[:kind][0, 1].downcase + o[:kind][1..-1] + "Value"
      dereferncingPrefix = ""
    end
    "#{memo}, #{dereferncingPrefix}((RolloutTypeWrapper*)arguments[#{index}]).#{value}" 
  } 
  arg_dec  = args.inject("")  { |memo, o|  
    "#{memo}, #{o[:type]} #{o[:name]}"
  }
  arg_dec_types_only  = args.inject("")  { |memo, o|  
    "#{memo}, #{o[:type]}"
  }

  t = scope[:type]
  call_original = "originalFunction(rcv, NSSelectorFromString(tweakId.methodId.selector)#{arg_names})"
  call_original_and_return = "#{call_original}; return [[RolloutTypeWrapper alloc] initWithVoid];"
  record_definition = ""
  final_return = ""

  arguments = ""
  args.each { |arg|
    if "Record" == arg[:kind]
      arguments << "     [[RolloutTypeWrapper alloc] initWithRecordPointer:&#{arg[:name]} ofSize:sizeof(#{arg[:type]}) shouldBeFreedInDealloc:NO], \n"
    else
      arguments << "     [[RolloutTypeWrapper alloc] initWith#{arg[:kind]}:#{arg[:name]}], \n"
    end
  }

  if args.length > 0
    tweaked_arguments = "NSArray *arguments = inv.tweakedArguments;"
  end

  if r != "void"
    call_original_and_return = "return [[RolloutTypeWrapper alloc] initWith#{r_k}:#{call_original}];"
    final_return = "return result.#{r_k[0, 1].downcase + r_k[1..-1]}Value;"
  end 
  if r_k == "Record"
    call_original_and_return = "record = #{call_original};\n        return [[RolloutTypeWrapper alloc] initWithRecordPointer:&record ofSize:sizeof(#{r}) shouldBeFreedInDealloc:NO];"
    record_definition = "__block #{r} record;"
    final_return = "return *(#{r} *)result.recordPointer;";
  end

  return "
- (id)blockFor_#{producer_signature}_withOriginalImplementation:(IMP)originalImplementation tweakId:(RolloutTweakId *)tweakId
{
  return ^#{r}(id rcv#{arg_dec}) {
    #{r} (*originalFunction)(id, SEL#{arg_dec_types_only}) = (void *) originalImplementation;
    NSArray *originalArguments = @[#{arguments}];
    #{record_definition}
    RolloutTypeWrapper *result __attribute__((unused)) = [self->_invocation invokeWithTweakId:tweakId originalArguments:originalArguments originalMethodWrapper:^RolloutTypeWrapper *(NSArray *arguments) {
        #{call_original_and_return}
    }];

    #{final_return}
  };
}
"
end #}}}

input = JSON.parse(File.read(ARGV[0]))
chunks_path = ARGV[1]
chunks_prefix = "#{chunks_path}/RolloutDynamic_"

def fix_type_issue(data) #{{{
  ["origin", "type"].each { |key|
    data[key].gsub!(/\bconst /, "") unless data[key].nil?
  }

 # Special - CXType_BlockPointer  CXType_Record   CXType_Enum  CXType_Pointer  CXType_ObjCObjectPointer  
  keep_types = [ "UShort","Char16","Char_U","Char16","Char32","Int128","UInt128","Bool","Float","Short","Long","WChar","ULong","Double","Int","Void","Char_S","UChar","SChar","LongLong","ULongLong","UInt","LongDouble"]
  case 
  when ["CGFloat", "BOOL"].include?(data["origin"])
    return { :type => data["origin"], :kind => data["kind"], :origin => data["origin"]}
  when "ObjCObjectPointer" == data["kind"]
    return { :type => "id", :kind => data["kind"]}
  when "Pointer" == data["kind"]
    return  { :type => "void*", :kind => data["kind"]}
  when "BlockPointer" == data["kind"]
    return { :type => "id", :kind => data["kind"]}
  when "Enum" == data["kind"]
    return { :type => "__rollout_enum", :kind => data["kind"]}
  when "Record" == data["kind"]
    return nil unless (/unsupported\$/ =~ data["struct_name"]).nil?
    return { :type =>  data["struct_name"], :origin => data["type"], :kind => data["kind"]}
  when keep_types.include?( data["kind"])
    return { :type => data["type"], :kind => data["kind"]}
  when "unsupported" == data["kind"]
    return nil
  else
    ErrorsReporter.report_error("Unknown kind in fix_type_issue", data)
    return nil
  end
end #}}}

def object_signature_type(object) #{{{
  kind = object[:kind]
  type = object[:type]
  origin = object[:origin]
  if kind == "Record"
    return "#{kind}_#{origin.gsub(" ", "_RolloutSpace_")}"
  end

  if ["CGFloat", "BOOL"].include? origin
    return origin
  end

  return kind
end #}}}

def struct_name(struct_hash) #{{{
  "__rollout_dummy_struct__#{struct_hash}"
end #}}}

#TODO change this function to return results_list and not to recieve it
def process_struct(all_structs_hash, processed_structs, struct_hash, results_list) #{{{
  return if processed_structs.include?(struct_hash)
  struct = all_structs_hash[struct_hash]
  struct["children"].each { |c|
    process_struct(all_structs_hash, processed_structs, c["record_data_ref"], results_list) if c["kind"] == "Record"  
  }
  results_list << struct_hash
  processed_structs << struct_hash
end #}}}

methods = input["data"].map { |arch_data|
    arch_data["data"]["methods"].flat_map {|c| c["children"]}
  }.flat_map {|array| array}
methods.each { |m| 
  m["args"].each { |a| 
    if a["kind"] == "Record"
      a["struct_name"] = struct_name(a["record_data_ref"])
    end
  }
  if m["return"]["kind"] == "Record"
    m["return"]["struct_name"] = struct_name(m["return"]["record_data_ref"])
  end
}

structs_output_filename = "#{chunks_prefix}structs.h"
processed_structs = `grep '^typedef struct ' "#{structs_output_filename}" | sed -e 's/^typedef struct __rollout_dummy_struct__//' -e 's/ {$//'`.split("\n").to_set()
source_structs_hash = input["data"].map {|arch_data| arch_data["data"]["structs"]}.reduce({}, :merge)
new_structs_list = []
source_structs_hash.keys.each { |struct_hash| 
  process_struct(source_structs_hash, processed_structs, struct_hash, new_structs_list)
}
structs_output = File.open(structs_output_filename, "a")
if File.size(structs_output_filename) == 0
  structs_output.puts "// This file is auto generated by Rollout.io SDK during application build process, it should be committed to you repository as part of your code. For more info please checkout the FAQ at http://support.rollout.io

#if defined(__LP64__) && __LP64__
# define CGFLOAT_TYPE double
# define CGFLOAT_IS_DOUBLE 1
# define CGFLOAT_MIN DBL_MIN
# define CGFLOAT_MAX DBL_MAX
#else
# define CGFLOAT_TYPE float
# define CGFLOAT_IS_DOUBLE 0
# define CGFLOAT_MIN FLT_MIN
# define CGFLOAT_MAX FLT_MAX
#endif
typedef CGFLOAT_TYPE CGFloat;

#if !defined(OBJC_HIDE_64) && TARGET_OS_IPHONE && __LP64__
typedef bool BOOL;
#else
typedef signed char BOOL;
#endif

"
end
if new_structs_list.length() > 0
  new_structs_list.each { |struct_hash|
    next unless (/unsupported\$/ =~ struct_hash).nil?
    struct = source_structs_hash[struct_hash]
    name = struct_name(struct_hash)
    structs_output.puts "typedef struct #{name} {"
    struct["children"].each { |c|
      next if c.empty?
      if(c["kind"] == "Record")
        type = struct_name(c["record_data_ref"])
      else
        c_with_fixed_type = fix_type_issue(c)
        next if c_with_fixed_type.nil?
        type = c_with_fixed_type[:type] 
      end
      structs_output.puts "  #{type} #{c["symbol"]};"
    }
    structs_output.puts "} #{name};"
  }
end
structs_output.close

producer_signatures_hash = {}
methods.each { |m|
  method_return_object = fix_type_issue(m["return"])
  arguments_with_types  = m["args"].map.with_index { |a, index|
    t  =  fix_type_issue(a)
    next t if t.nil?
    t[:name] = "arg#{index}"
    t
  }

  next if method_return_object.nil? || (arguments_with_types.include? nil)

  method_type = m["kind"] == "instance" ? "instanceMethod" : "classMethod"
  method_signature_args = [object_signature_type(method_return_object)]
  arguments_with_types.each{|o| method_signature_args << object_signature_type(o)}
  method_signature = method_signature_args.join "___"

  producer_signature = "#{method_type}_#{method_signature}"
  signature_data = {
    :return_object => method_return_object,
    :type =>  m["kind"] == "instance" ? "Instance" : "Class",
    :args => arguments_with_types,
    :producer_signature => producer_signature
  }

  if producer_signatures_hash.has_key? producer_signature
    if false and signature_data != producer_signatures_hash[producer_signature]
      ErrorsReporter.report_error("Different method objects share the same signature", {
        :signature => producer_signature,
        :objectA => producer_signatures_hash[producer_signature],
        :objectB => signature_data
      })
    end
    next
  end

  producer_signatures_hash[producer_signature] = signature_data
}

number_of_chunks = 20
file_names = (1..number_of_chunks).map { |chunk| "#{chunks_prefix}#{"%02d" % chunk}.m" }

existing_signatures_by_chunk = file_names.map.with_index { |file, index|
  if File.size(file) > 0
    `grep "^- (id)blockFor_" "#{file}" | sed -e 's/^- (id)blockFor_//' -e 's/_withOriginalImplementation:.*$//'`.split("\n")
  else
    File.write(file, "// This file is auto generated by Rollout.io SDK during application build process, it should be committed to you repository as part of your code. For more info please checkout the FAQ at http://support.rollout.io

#import <Rollout/private/RolloutDynamic.h>
#import <Rollout/private/RolloutInvocation.h>
#import <Rollout/private/RolloutTypeWrapper.h>
#import <Rollout/private/RolloutInvocationsListFactory.h>
#import <Rollout/private/RolloutErrors.h>
#import <Rollout/private/RolloutMethodId.h>
#import <Rollout/private/RolloutTweakId.h>
#import <Rollout/private/RolloutConfiguration.h>
#import <objc/objc.h>

#import \"RolloutDynamic_structs.h\"

@implementation RolloutDynamic(blocks_#{index + 1})

@end
")
    []
  end
}

current_signatures_by_chunk = file_names.map { |file| [] }
producer_signatures_hash.values.each { |signature_data|
  signature = signature_data[:producer_signature]
  chunk = Zlib.crc32(signature).modulo(number_of_chunks)
  current_signatures_by_chunk[chunk].push(signature)
}

new_signatures_by_chunk = (0..number_of_chunks - 1).map { |chunk|
  current_signatures_by_chunk[chunk] - existing_signatures_by_chunk[chunk]
}

new_signatures_by_chunk.each.with_index { |signatures, index|
  next if signatures.length == 0
  file_name = file_names[index]
  `/usr/bin/sed -i "" -e '/^@end$/d' "#{file_name}" > /dev/null`
  open(file_name, 'a') { |f|
    signatures.each { |signature|
      f.puts wrapping(producer_signatures_hash[signature])
    }
    f.puts "@end"
  }
  puts(file_names[index].split("/").last().split(".")[0])
}
