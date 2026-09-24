// rename-session — opencode port of the qa-manager `rename-session` hook.
//
// The original was a Claude Code hook with two launch paths, two events:
//  - UserPromptSubmit (no matcher): the user typed «/qa …» or «/qa-manager:qa …» as a slash
//    command — the skill is injected without invoking the Skill tool;
//  - PreToolUse (matcher: Skill): Claude invoked the `qa` skill through the tool (e.g. from
//    the phrase «test task X»).
//
// opencode equivalents:
//  - «/qa …» dispatches the `qa` command (`.opencode/commands/qa.md`) and fires the
//    `command.executed` event — handled through the `event` subscription;
//  - a skill load fires the `tool.execute.before` hook for the `skill` tool — handled via the
//    hook. Note the opencode Skill tool takes only `{ name }` (no free-text task argument),
//    so this path renames when the task number can still be read from the invocation context.
//
// The session is renamed to the task number taken from the arguments, via the SDK's
// `session.update` — the session title becomes «Task <num>».
export const RenameSession = async ({ client }) => {
  // Priority: a link to a work item / issue → the #<num> form → the last number.
  // stageN is dropped in advance («ACME-449 on stage3» ≠ task 3); the last number rather than
  // the first, because in a URL like .../group/team/project/-/work_items/676 the first number
  // is the «2» in the group name.
  function taskNumber(args) {
    const clean = String(args || "").replace(/stage[0-9]+/g, "");
    const item = clean.match(/(?:work_items|issues)\/[0-9]+/);
    if (item) return item[0].split("/")[1] || null;
    const hash = clean.match(/#[0-9]+/);
    if (hash) return hash[0].slice(1) || null;
    const numbers = clean.match(/[0-9]+/g);
    return numbers ? numbers[numbers.length - 1] : null;
  }

  async function rename(sessionID, num) {
    if (!num || !sessionID) return;
    await client.session.update({
      path: { id: sessionID },
      body: { title: `Task ${num}` },
    });
  }

  return {
    event: async ({ event }) => {
      if (event.type !== "command.executed") return;
      const { name, sessionID, arguments: args } = event.properties || {};
      if (name !== "qa" && name !== "qa-manager:qa") return;
      await rename(sessionID, taskNumber(args));
    },

    "tool.execute.before": async (input, output) => {
      if (!input || input.tool !== "skill") return;
      const name = output?.args?.name;
      if (name !== "qa" && name !== "qa-manager:qa") return;
      await rename(input.sessionID, taskNumber(output.args.arguments ?? output.args.args));
    },
  };
}