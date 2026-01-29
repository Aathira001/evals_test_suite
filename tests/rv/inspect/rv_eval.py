import os
from inspect_ai import Task, task
from inspect_ai.dataset import csv_dataset
from inspect_ai.scorer import model_graded_qa
from inspect_ai.solver import generate, system_message, use_tools
from inspect_ai.model import get_model, GenerateConfig
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))                                      


@task
def rv_persona_eval(system=None, grader=None, data_path=None, task_name=None, tool_calling: bool=False, message_limit: int|None=None, temperature: float|None=None, grader_model: str|None=None):
    # Use config parameters if provided, otherwise fall back to defaults
    if system is None:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        system = os.path.join(base_path, "prompts", "rv.md")
    
    if grader is None:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        grader = os.path.join(base_path, "prompts", "scorer_rv.md")
    
    if data_path is None:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        data_path = os.path.join(base_path, "data", "rv_qna_fixed.csv")
        
    if task_name is None:
        task_name = "rv_persona_eval"
        
    if tool_calling is None:
        tool_calling = False
        
    if message_limit is None:
        message_limit = None
        
    if temperature is None:
        temperature = 0.0

    if grader_model is None:
        grader_model = "anthropic/bedrock/us.anthropic.claude-sonnet-4-5-20250929-v1:0"
        
    # Read prompt files
    with open(system, 'r') as f:
        system_prompt = f.read()
    
    with open(grader, 'r') as f:
        grader_prompt = f.read()
    
    grader_model_instance = get_model(
        grader_model,
        config=GenerateConfig(temperature=0.0)
    )
        

    solver = [
        system_message(system_prompt), 
        generate()
    ]
    
    return Task(
        name=task_name,
        dataset=csv_dataset(data_path),
        solver=solver,
        scorer=model_graded_qa(
            instructions=grader_prompt,
            model=grader_model_instance
        ),
        message_limit=message_limit,
        temperature=temperature
    )