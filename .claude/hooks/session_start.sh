#!/bin/bash
# SessionStart hook: показывает агенту и аналитику состояние проектов.
# Всё, что выводится в stdout, попадает в контекст Claude в начале сессии.

PROJECTS_DIR="$CLAUDE_PROJECT_DIR/projects"

echo "=== SA Agent ==="
echo ""

if [ -d "$PROJECTS_DIR" ] && [ -n "$(ls -A "$PROJECTS_DIR" 2>/dev/null)" ]; then
    echo "📁 Проекты:"
    for dir in "$PROJECTS_DIR"/*/; do
        [ -d "$dir" ] || continue
        pid=$(basename "$dir")
        n_out=$(find "$dir/outputs" -type f ! -name '.gitkeep' 2>/dev/null | wc -l | tr -d ' ')
        ctx="контекст ✓"
        [ -f "$dir/project_context.md" ] || ctx="⚠️ нет project_context.md"
        echo "   • $pid — артефактов: $n_out, $ctx"

        # Новые входные файлы (моложе последнего артефакта или все, если артефактов нет)
        newest_out=$(find "$dir/outputs" -type f ! -name '.gitkeep' -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
        newest_out=${newest_out%.*}
        newest_out=${newest_out:-0}
        find "$dir/inputs" -maxdepth 2 -type f ! -name '.gitkeep' -printf '%T@ %P\n' 2>/dev/null | \
            while read ts name; do
                [ "${ts%.*}" -gt "$newest_out" ] && echo "       📥 новый вход: inputs/$name"
            done
    done
    echo ""

    echo "📄 Последние артефакты:"
    find "$PROJECTS_DIR" -path '*/outputs/*' -type f ! -name '.gitkeep' ! -name '*.confluence.md' -printf '%T@ %P\n' 2>/dev/null | \
        sort -rn | head -5 | while read ts path; do echo "   • projects/$path"; done
    echo ""
else
    echo "📁 Проектов пока нет. Скажи: «Новый проект: <название>»."
    echo ""
fi

echo "💡 Назови проект и задачу обычным языком: «loans: декомпозируй inputs/task-123.txt»."
