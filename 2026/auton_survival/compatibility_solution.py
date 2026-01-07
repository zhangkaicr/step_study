

#####################################
# 解决Progress not found警告问题(不影响运行)
#####################################

# 导入 warnings 模块，用于控制 Python 的警告信息
import warnings
# 从 tqdm.auto 中导入 tqdm，并起别名为 notebook_tqdm
# tqdm.auto 会自动检测运行环境（如 Jupyter Notebook、IPython、终端等），

# 并选择最适合的进度条实现（在 Notebook 中优先使用 ipywidgets 的进度条）
from tqdm.auto import tqdm as notebook_tqdm

# 忽略特定的 TqdmWarning：当 Jupyter 环境中未安装或版本过旧的 ipywidgets 时，
# tqdm 会抛出 "IProgress not found. Please update jupyter and ipywidgets." 警告。
# 通过 warnings.filterwarnings 将该警告静默，避免干扰用户
warnings.filterwarnings("ignore", message="IProgress not found. Please update jupyter and ipywidgets.")

# #####################################
# ### 解决 matplotlib.legend.Legend 类缺少 legendHandles 属性的问题####
# #####################################
# # 导入 matplotlib 库
# import matplotlib

# # 检查 matplotlib.legend.Legend 类是否缺少 legendHandles 属性
# # 这样做是为了让代码更健壮，避免在已经存在该属性的旧版本上执行时可能引发问题
# if not hasattr(matplotlib.legend.Legend, 'legendHandles'):
    
#     # 为 Legend 类动态添加一个名为 legendHandles 的属性
#     # 新版本的 matplotlib 使用 'legend_handles' 来存储图例句柄
#     # 我们使用 property() 函数创建一个别名，当代码访问 legendHandles 时，
#     # 它会被自动重定向去获取 legend_handles 的值。
#     # 这样，依赖旧属性名的 pandas 代码就能在新版 matplotlib 上正常工作。
#     matplotlib.legend.Legend.legendHandles = property(lambda self: self.legend_handles)

# fix_matplotlib_legend.py
import matplotlib

def fix_legend_handles():
    """修复 matplotlib Legend 类缺少 legendHandles 属性的问题，全局生效"""
    if not hasattr(matplotlib.legend.Legend, 'legendHandles'):
        matplotlib.legend.Legend.legendHandles = property(lambda self: self.legend_handles)
        return True
    return False