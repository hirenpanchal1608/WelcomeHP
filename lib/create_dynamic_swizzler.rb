#!/usr/bin/env ruby

require "JSON"
require 'zlib'
require_relative "errors_reporter"

if ARGV.length != 3
  STDERR.puts "Usage:\n$0: <input_json> <output_chunks_prefix> <arch>"
  exit 1
end

def wrapping(scope)
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

  t = scope[:type]
  call_store = "originalFunction(rcv, NSSelectorFromString(methodId.selector)#{arg_names})"
  set_original_return_value = "#{call_store};"
  set_original_return_value_if_nil_invocation = "originalFunction(rcv, NSSelectorFromString(methodId.selector)#{arg_list});"
  set_original_return_value_if_nil_invocation_with_return = "#{set_original_return_value_if_nil_invocation} return;"
  declare_wrapper_r = "" 
  return_var = ""
  return_expression = "return;"
  sync_declare_r = "" 
  sync_set_r = "swizzleBlock();"
  sync_return_r = "return;"
  async_return_r = "return;"
  final_return = "swizzleBlock(); return;"
  replaceReturnValue = ""
  defaultReturnValue = ""

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
    return_var = "__rollout_r"
    set_original_return_value = "inv.originalReturnValue = [[RolloutTypeWrapper alloc] initWith#{r_k}:#{call_store}];"
    set_original_return_value_if_nil_invocation_with_return = "return #{set_original_return_value_if_nil_invocation}"
    declare_wrapper_r= "RolloutTypeWrapper *#{return_var};"
    sync_declare_r = "#{r} $; " + ("ObjCObjectPointer" == r_k || "BlockPointer" == r_k ? "__strong " : "") + "#{r}* $p = &$;"
    sync_set_r = "*$p = swizzleBlock();"
    sync_return_r = "return $;"
    async_return_r = "return inv.defaultReturnValue.#{r_k[0, 1].downcase}#{r_k[1..-1]}Value;"
    final_return = "return swizzleBlock();"
    return_expression = "return #{return_var}.#{r_k[0, 1].downcase}#{r_k[1..-1]}Value;";
    defaultReturnValue = "#{return_var} = [inv defaultReturnValue];"
    replaceReturnValue = "#{return_var} =   [inv conditionalReturnValue];"
  end 
  if r_k == "Record"
    set_original_return_value = "{#{r} record = #{call_store};\n              inv.originalReturnValue = [[RolloutTypeWrapper alloc] initWithRecordPointer:&record ofSize:sizeof(#{r}) shouldBeFreedInDealloc:NO];}"
    return_expression = "return *(#{r} *)#{return_var}.recordPointer;";
    async_return_r = "return *(#{r} *)inv.defaultReturnValue.recordPointer;"
  end

  swizzle_block_content = "\
        #{declare_wrapper_r}
        [inv runBefore];
    
        inv.originalArguments = originalArguments;
        #{tweaked_arguments}
    
        switch ([inv type]) {
            case RolloutInvocationTypeDisable:
                #{defaultReturnValue}
                break;
            case RolloutInvocationTypeTryCatch:
                @try{
                  #{set_original_return_value}
                  #{replaceReturnValue}
                }
                @catch(id e){
                    [inv runAfterExceptionCaught];
                    #{defaultReturnValue}
                }
                break;
            case RolloutInvocationTypeNormal:
            default:
                  #{set_original_return_value};
                  #{replaceReturnValue}
                break;
        }
        #{return_expression}"

  return "
- (id)blockFor_#{producer_signature}_withOriginalImplementation:(IMP)originalImplementation methodId:(RolloutMethodId *)methodId
{
  return ^#{r}(id rcv#{arg_dec}) {
    #{r} (*originalFunction)(id rcv, SEL _cmd#{arg_dec}) = (void *) originalImplementation;

    NSArray *originalArguments = @[#{arguments}];
    NSArray *tweakConfiguration = self->_configuration.configurationsByMethodId[methodId];
    RolloutInvocationsList *invocationsList = [self->_invocationsListFactory invocationsListFromTweakConfiguration:tweakConfiguration];
    RolloutInvocation *inv = [invocationsList invocationForArguments:originalArguments];
    
    if(!inv) {
       #{set_original_return_value_if_nil_invocation_with_return}
    }

    if(inv.forceMainThreadType == RolloutInvocation_ForceMainThreadType_off || [NSThread isMainThread]) {
#{swizzle_block_content}
    }

    #{r} (^swizzleBlock)() = ^#{r}() {
#{swizzle_block_content}
    };

    switch(inv.forceMainThreadType) {
        case RolloutInvocation_ForceMainThreadType_sync: {
            #{sync_declare_r}
            id exception = nil, __strong *exceptionPointer = &exception;

            dispatch_sync(dispatch_get_main_queue(), ^{
	        @try {
                    #{sync_set_r}
                } @catch(id exception) {
                    *exceptionPointer = exception;
                }
            });
            if(exception) {
                @throw exception;
            }
            #{sync_return_r}
        }
        case RolloutInvocation_ForceMainThreadType_async: {
            dispatch_async(dispatch_get_main_queue(), ^{
                swizzleBlock();
            });
            #{async_return_r}
        }
        case RolloutInvocation_ForceMainThreadType_off:
        case RolloutInvocation_ForceMainThreadTypesCount:
            break;
    }
    #{final_return}
  };
}
"
end

input = JSON.parse(File.read(ARGV[0]))
chunks_prefix = ARGV[1]
#arch = ARGV[2]
symbols = input["methods"].flat_map {|c| c["children"]}
$structs = input["structs"]

ignored_types = ["ConstantArray", "IncompleteArray", "FunctionProto", "Invalid", "Unexposed", "NullPtr","Overload","Dependent","ObjCId","ObjCClass","ObjCSel","FirstBuiltin","LastBuiltin","Complex","LValueReference","RValueReference","Typedef","ObjCInterface","FunctionNoProto","Vector","VariableArray","DependentSizedArray","MemberPointer"]

def fix_type_issue(data)
  ["origin", "type"].each { |key|
    data[key].gsub!(/\bconst /, "") unless data[key].nil?
  }

 # Special - CXType_BlockPointer  CXType_Record   CXType_Enum  CXType_Pointer  CXType_ObjCObjectPointer  
  keep_types = [ "UShort","Char16","Char_U","Char16","Char32","Int128","UInt128","Bool","Float","Short","Long","WChar","ULong","Double","Int","Void","Char_S","UChar","SChar","LongLong","ULongLong","UInt","LongDouble"]
  case 
  when ["CGFloat", "BOOL"].include?(data["origin"])
    return { :type => data["type"], :kind => data["kind"], :origin => data["origin"]}
  when "ObjCObjectPointer" == data["kind"]
    return { :type => "id", :kind => data["kind"]}
  when "Pointer" == data["kind"]
    return  { :type => "void*", :kind => data["kind"]}
  when "BlockPointer" == data["kind"]
    return { :type => "id", :kind => data["kind"]}
  when "Enum" == data["kind"]
    return { :type => "__rollout_enum", :kind => data["kind"]}
  when "Record" == data["kind"]
    return { :type =>  data["struct_name"], :origin => data["type"], :kind => data["kind"]}
  when keep_types.include?( data["kind"])
    return { :type => data["type"], :kind => data["kind"]}
  else
    ErrorsReporter.report_error("Unknown kind in fix_type_issue", data)
    return nil
  end
end


extract_arguments_with_types = lambda { |a, index|
  t  =  fix_type_issue(a)
  return t if t.nil?
  t[:name] = "arg#{index}"
  t
}

valid_for_swizzeling  = lambda { |m|
  puts "//#{m["symbol"]} removed" if m["__should_be_removed"]
  return false if m["__should_be_removed"]
  return false if m["symbol"] == "dealloc" 
  true
}
def struct_name(a)
  ref = a["record_data_ref"]
  $structs[ref]["name"]
end
def object_signature_type(object)
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
end

defines = []
symbols.each.select(&valid_for_swizzeling).each { |m| 
  m["args"].each { |a| 
    m["__should_be_removed"] = true if ignored_types.include?( a["kind"]) or a["kind"].nil?
    if a["kind"] == "Record"
      a["struct_name"] = struct_name(a)
    end
  }
  m["__should_be_removed"] = true  if ignored_types.include?( m["return"]["kind"]) or m["return"]["kind"].nil?
  if m["return"]["kind"] == "Record"
    m["return"]["struct_name"] = struct_name(m["return"])
  end
}

def print_struct(s, output)
  return if s["printed"]
  s["children"].each { |c|
    print_struct($structs[c["record_data_ref"]], output) if c["kind"] == "Record"  
  }
  name = s["name"]
  output.puts "typedef struct #{name} {"
  s["children"].each { |c|
    next if c.empty?
    type = c["kind"] == "Record" ? $structs[c["record_data_ref"]]["name"] : fix_type_issue(c)[:type] 
    output.puts "  #{type} #{c["symbol"]};"
  }
  output.puts "} #{name};"
  s["printed"] = true
end

structs_output_filename = "#{chunks_prefix}structs.h"
structs_output = File.open(structs_output_filename, "w")
$structs.values.each { |s| 
  print_struct(s, structs_output)
}
defines.uniq().each { |i|
  structs_output.puts "#import #{i}"
}
structs_output.close

producer_signatures_hash = {}
symbols.each.select(&valid_for_swizzeling).each { |m| 
  method_return_object = fix_type_issue(m["return"])
  arguments_with_types  = m["args"].map.with_index(&extract_arguments_with_types)

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

number_of_chunks = [[4, producer_signatures_hash.keys.length / 40].max, 400].min
outputs = []
(0..number_of_chunks).to_a.each { |chunk|
  chunk_string = "%03d" % chunk
  output = File.open("#{chunks_prefix}#{chunk_string}.m", "w")
  outputs.push(output)
  output.puts "
#import <Rollout/private/RolloutDynamic.h>
#import <Rollout/private/RolloutInvocation.h>
#import <Rollout/private/RolloutTypeWrapper.h>
#import <Rollout/private/RolloutInvocationsListFactory.h>
#import <Rollout/private/RolloutErrors.h>
#import <Rollout/private/RolloutMethodId.h>
#import <Rollout/private/RolloutConfiguration.h>
#import <objc/objc.h>

#import \"{{ROLLOUT_TEMPLATE__structs_file}}\"
"

  if chunk == 0
    output.puts "
@implementation RolloutDynamic(arch)
+ (NSString *)currentArch {return @\"#{$arch}\";} 
@end"
  end

  output.puts "
@implementation RolloutDynamic(blocks_#{chunk_string})
"
}

producer_signatures_hash.values.each { |signature_data|
  chunk = Zlib.crc32(signature_data[:producer_signature]).modulo(number_of_chunks)
  outputs[chunk].puts wrapping(signature_data)
}

outputs.each { |output|
  output.puts "@end"
  output.close
}
