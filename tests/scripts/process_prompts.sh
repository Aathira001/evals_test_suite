#!/bin/bash

# Process prompts script
# Usage: process_prompts.sh TYPE PATTERN TARGET_DIR [FILE_LIST] [TOOL_CALL] [DATASET_NAME]  

process_prompts() {
  local TYPE=$1
  local PATTERN=$2
  local TARGET_DIR=$3
  local FILE_LIST=$4
  local ALL_EVAL_LOG=$5
  local DATASET_NAME=$6

  # Determine repository root directory
  # Script is in tests/scripts/, so go up two levels to get repo root
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  
  # Convert log file path to absolute if it's relative
  if [[ "$ALL_EVAL_LOG" != /* ]]; then
    # If relative, make it relative to repo root
    ALL_EVAL_LOG="$REPO_ROOT/$ALL_EVAL_LOG"
  fi
  
  # Ensure log file directory exists
  mkdir -p "$(dirname "$ALL_EVAL_LOG")"
  
  echo "📁 Repository root: $REPO_ROOT"
  echo "📁 Script directory: $SCRIPT_DIR"
  echo "📝 Log file: $ALL_EVAL_LOG"

  if [[ -n "$FILE_LIST" ]]; then
    YAML_FILES="$FILE_LIST"
  else
    YAML_FILES=$(find "$REPO_ROOT/prompts/prompt_templates/" -name "$PATTERN" -type f | sort -r)
  fi

  if [[ -z "$YAML_FILES" ]]; then
    echo "⚠️ No YAML files found for $TYPE in $REPO_ROOT/prompts/prompt_templates/"
    return
  else
    echo "YAML FILES FOUND for $TYPE: $(echo "$YAML_FILES" | wc -w)"
    echo "Files: $YAML_FILES"
  fi

  for YAML_FILE in $YAML_FILES; do
    YAML_NAME=$(basename "$YAML_FILE" .yaml)
    MD_FILE="${YAML_NAME}.md"
    echo ""
    echo "============================================================"
    echo ">>> STARTING NEW RUN: $YAML_NAME"
    echo "YAML: $YAML_FILE"
    echo "MD:   $MD_FILE"
    echo "============================================================"
    echo ""

    # Read tool_call setting from YAML file
    TOOL_CALL=$(grep "^tool_call:" "$YAML_FILE" | sed 's/tool_call: *//' | tr -d ' ')
    if [[ -z "$TOOL_CALL" ]]; then
      TOOL_CALL="false"  # default to false if not specified
    fi
    echo "🔧 Tool calling setting from YAML: $TOOL_CALL"

    # Extract prompt to markdown
    python "$REPO_ROOT/tests/scripts/extract_prompt.py" "$YAML_FILE"
    echo "✅ Extracted prompt to markdown"

    MD_PATH="$REPO_ROOT/prompts/prompt_templates/$MD_FILE"

    if [[ -f "$MD_PATH" ]]; then
      mkdir -p "$REPO_ROOT/tests/$TARGET_DIR/prompts"
      mv "$MD_PATH" "$REPO_ROOT/tests/$TARGET_DIR/prompts/$MD_FILE"
      echo "✅ Moved $MD_FILE from prompts/prompt_templates/ to tests/$TARGET_DIR/prompts/"
    else
      echo "⚠️ $MD_FILE not found at $REPO_ROOT/prompts/prompt_templates/"
      exit 1
    fi

    # Create log directory
    LOG_DIR="$REPO_ROOT/logs/${RUN_TIMESTAMP}/${TARGET_DIR}"
    mkdir -p "$LOG_DIR"

    # Copy prompt scorer to tests/$TARGET_DIR/prompts/
    SCORER_SOURCE="$REPO_ROOT/prompts/scorer_prompt_templates/scorer_$MD_FILE"
    if [[ -f "$SCORER_SOURCE" ]]; then
      cp "$SCORER_SOURCE" "$REPO_ROOT/tests/$TARGET_DIR/prompts/scorer_$MD_FILE"
      echo "✅ Copied scorer_$MD_FILE to tests/$TARGET_DIR/prompts/"
    else
      echo "⚠️ Scorer file not found at $SCORER_SOURCE"
      exit 1
    fi

    cd "$REPO_ROOT/tests/$TARGET_DIR/inspect"

    # Update config.yaml to point to the new markdown file
    if [[ -f "config.yaml" ]]; then
      sed -i.bak "s|system: \".*\"|system: \"../prompts/$MD_FILE\"|" config.yaml
      sed -i.bak "s|grader: \".*\"|grader: \"../prompts/scorer_$MD_FILE\"|" config.yaml
      TASK_NAME="${YAML_NAME}"
      sed -i.bak "s|task_name: \".*\"|task_name: \"${TASK_NAME}\"|" config.yaml
      sed -i.bak "s|data_path: \".*\"|data_path: \"../data/${DATASET_NAME}.csv\"|" config.yaml
      # Update tool_calling based on YAML file setting
      if [[ "$TOOL_CALL" == "true" ]]; then
        sed -i.bak "s|tool_calling: .*|tool_calling: True|" config.yaml
        echo "✅ Set tool_calling to True (from YAML)"
      else
        sed -i.bak "s|tool_calling: .*|tool_calling: False|" config.yaml
        echo "✅ Set tool_calling to False (from YAML)"
      fi
      
      echo "✅ Updated config.yaml to point to ../prompts/$MD_FILE and scorer_${MD_FILE} and set task_name to $TASK_NAME and dataset_name to $DATASET_NAME"
    else
      echo "⚠️ config.yaml not found"
      exit 1
    fi

    # Activate environment
    # Note: This assumes the venv is in tests/.venv (as set up in GitHub Actions)
    if [[ -f "$REPO_ROOT/tests/.venv/bin/activate" ]]; then
      source "$REPO_ROOT/tests/.venv/bin/activate"
    elif [[ -f "$REPO_ROOT/eval_suite/bin/activate" ]]; then
      source "$REPO_ROOT/eval_suite/bin/activate"
    else
      echo "⚠️ Virtual environment not found. Trying relative path..."
      source ../../../eval_suite/bin/activate || source ../../../.venv/bin/activate
    fi
    echo "set logfile to $ALL_EVAL_LOG"

    # Read models from config.yaml or use defaults
    EVAL_MODEL=$(grep "^model:" config.yaml | sed 's/model: *//' | tr -d '"' | tr -d ' ')
    GRADER_MODEL=$(grep "^grader_model:" config.yaml | sed 's/grader_model: *//' | tr -d '"' | tr -d ' ')

    # Fallback to defaults if not found in config
    if [[ -z "$EVAL_MODEL" ]]; then
      EVAL_MODEL="anthropic/bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0"
      echo "⚠️ No model found in config.yaml, using default: $EVAL_MODEL"
    fi

    if [[ -z "$GRADER_MODEL" ]]; then
      GRADER_MODEL="anthropic/bedrock/us.anthropic.claude-sonnet-4-5-20250929-v1:0"
      echo "⚠️ No grader_model found in config.yaml, using default: $GRADER_MODEL"
    fi

    echo ""
    echo "🤖 Evaluation Model: $EVAL_MODEL"
    echo "🎯 Grader Model: $GRADER_MODEL"
    echo ""

    # Also write model info to log file
    echo "" >> "$ALL_EVAL_LOG"
    echo "🤖 Evaluation Model: $EVAL_MODEL" >> "$ALL_EVAL_LOG"
    echo "🎯 Grader Model: $GRADER_MODEL" >> "$ALL_EVAL_LOG"
    echo "" >> "$ALL_EVAL_LOG"

    # Run the evaluation script
    # ALL_EVAL_LOG is already absolute at this point
    inspect eval ${TARGET_DIR}_eval.py \
      --task-config=config.yaml \
      --model=$EVAL_MODEL \
      --model-role grader=$GRADER_MODEL \
      --temperature 0.0 \
      --cache-prompt=true \
      --log-dir $LOG_DIR | tee -a "$ALL_EVAL_LOG"

    echo "✅ Evaluation completed for $MD_FILE"

    cd "$REPO_ROOT"
    echo ""
    echo "------------------------------------------------------------"
    echo ">>> COMPLETED RUN: $YAML_NAME"
    echo "------------------------------------------------------------"
    echo ""
  done
}

# Main execution if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  process_prompts "$@"
fi