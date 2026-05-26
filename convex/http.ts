import { httpRouter } from "convex/server";
import { api, internal } from "./_generated/api";
import { httpAction } from "./_generated/server";
import { auth } from "./auth";

const http = httpRouter();

auth.addHttpRoutes(http);

http.route({
  path: "/api/auth/session",
  method: "GET",
  handler: httpAction(async (ctx) => {
    let identity = null;
    try {
      identity = await ctx.auth.getUserIdentity();
    } catch {
      // Invalid/stale bearer tokens should not break app bootstrap.
      // Return unauthenticated so client can show login and recover.
      identity = null;
    }
    const data = identity
      ? { authenticated: true, userId: identity.subject }
      : { authenticated: false };

    return jsonOk(data);
  }),
});

http.route({
  path: "/api/auth/sign-in",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = (await request.json()) as { email?: string; password?: string };
    const email = (body.email ?? "").trim().toLowerCase();
    const password = (body.password ?? "").trim();

    if (!email || !password) {
      return jsonError(422, "validation", "Enter both email and password.");
    }

    const result = (await ctx.runAction(api.auth.signIn, {
      provider: "password",
      params: {
        flow: "signIn",
        email,
        password,
      },
    })) as {
      tokens?: { token?: string; refreshToken?: string } | null;
    };

    if (!result?.tokens?.token) {
      return jsonError(401, "unauthorized", "Email or password is incorrect.");
    }

    return jsonOk({
      authenticated: true,
      token: result.tokens.token,
      refreshToken: result.tokens.refreshToken ?? null,
      userId: email,
    });
  }),
});

http.route({
  path: "/api/auth/sign-out",
  method: "POST",
  handler: httpAction(async (ctx) => {
    await ctx.runAction(api.auth.signOut, {});
    return jsonOk({});
  }),
});

// Expenses
routeGet("/api/expenses/month-bounds", (ctx) => ctx.runQuery(api.expenses.monthBounds, {}));
routePost("/api/expenses/list-by-date-scope", (ctx, body) => ctx.runQuery(api.expenses.listByDateScope, body));
routePost("/api/expenses/create", (ctx, body) => ctx.runMutation(api.expenses.create, body));
routePost("/api/expenses/update", (ctx, body) => ctx.runMutation(api.expenses.update, body));
routePost("/api/expenses/remove", (ctx, body) => ctx.runMutation(api.expenses.remove, body));
routePost("/api/expenses/bulk-create", (ctx, body) => ctx.runMutation(api.expenses.bulkCreate, body));
routePost("/api/expenses/bulk-patch-visible", (ctx, body) => ctx.runMutation(api.expenses.bulkPatchVisible, body));
routePost("/api/expenses/rename-base-expense", (ctx, body) => ctx.runMutation(api.expenses.renameBaseExpense, body));
routePost("/api/expenses/remove-base-expense", (ctx, body) => ctx.runMutation(api.expenses.removeBaseExpense, body));
routePost("/api/expenses/add-partner-expense", (ctx, body) => ctx.runMutation(api.expenses.addPartnerExpense, body));
routePost("/api/expenses/unlink-expense-from-partners", (ctx, body) => ctx.runMutation(api.expenses.unlinkExpenseFromPartners, body));

// Incomings
routeGet("/api/incomings/month-bounds", (ctx) => ctx.runQuery(api.incomings.monthBounds, {}));
routePost("/api/incomings/list-by-date-scope", (ctx, body) => ctx.runQuery(api.incomings.listByDateScope, body));
routePost("/api/incomings/create", (ctx, body) => ctx.runMutation(api.incomings.create, body));
routePost("/api/incomings/update", (ctx, body) => ctx.runMutation(api.incomings.update, body));
routePost("/api/incomings/remove", (ctx, body) => ctx.runMutation(api.incomings.remove, body));
routePost("/api/incomings/bulk-create", (ctx, body) => ctx.runMutation(api.incomings.bulkCreate, body));
routePost("/api/incomings/bulk-patch-visible", (ctx, body) => ctx.runMutation(api.incomings.bulkPatchVisible, body));
routePost("/api/incomings/add-partner-incoming", (ctx, body) => ctx.runMutation(api.incomings.addPartnerIncoming, body));
routePost("/api/incomings/unlink-incoming-from-partners", (ctx, body) => ctx.runMutation(api.incomings.unlinkIncomingFromPartners, body));

// Recurrings
routePost("/api/recurrings/list", (ctx, body) => ctx.runQuery(api.recurrings.list, body));
routePost("/api/recurrings/create", (ctx, body) => ctx.runMutation(api.recurrings.create, body));
routePost("/api/recurrings/update", (ctx, body) => ctx.runMutation(api.recurrings.update, body));
routePost("/api/recurrings/remove", (ctx, body) => ctx.runMutation(api.recurrings.remove, body));
routePost("/api/recurrings/set-status", (ctx, body) => ctx.runMutation(api.recurrings.setStatus, body));
routePost("/api/recurrings/materialize-due-expenses", (ctx, body) => ctx.runMutation(api.recurrings.materializeDueExpenses, body));
routePost("/api/recurrings/cleanup-recurring-kind-fields", (ctx) => ctx.runMutation(api.recurrings.cleanupRecurringKindFields, {}));
routePost("/api/recurrings/migrate-legacy-recurrings-for-user-ids", (ctx, body) => ctx.runMutation(internal.recurrings.migrateLegacyRecurringsForUserIds, body));

// Summaries + Tracking
routePost("/api/summaries/range", (ctx, body) => ctx.runQuery(api.summaries.range, body));
routeGet("/api/tracking/list", (ctx) => ctx.runQuery(api.tracking.list, {}));

// Notepad
routeGet("/api/notepad/get-mine", (ctx) => ctx.runQuery(api.notepad.getMine, {}));
routePost("/api/notepad/add-note", (ctx, body) => ctx.runMutation(api.notepad.addNote, body));
routePost("/api/notepad/cleanup-empty-notes", (ctx) => ctx.runMutation(api.notepad.cleanupEmptyNotes, {}));
routePost("/api/notepad/rename-note", (ctx, body) => ctx.runMutation(api.notepad.renameNote, body));
routePost("/api/notepad/save-note-content", (ctx, body) => ctx.runMutation(api.notepad.saveNoteContent, body));
routePost("/api/notepad/add-table", (ctx) => ctx.runMutation(api.notepad.addTable, {}));
routePost("/api/notepad/rename-table", (ctx, body) => ctx.runMutation(api.notepad.renameTable, body));
routePost("/api/notepad/delete-table", (ctx, body) => ctx.runMutation(api.notepad.deleteTable, body));
routePost("/api/notepad/save-cell", (ctx, body) => ctx.runMutation(api.notepad.saveCell, body));
routePost("/api/notepad/add-row", (ctx, body) => ctx.runMutation(api.notepad.addRow, body));
routePost("/api/notepad/add-column", (ctx, body) => ctx.runMutation(api.notepad.addColumn, body));
routePost("/api/notepad/remove-last-row", (ctx, body) => ctx.runMutation(api.notepad.removeLastRow, body));
routePost("/api/notepad/remove-last-column", (ctx, body) => ctx.runMutation(api.notepad.removeLastColumn, body));

// User options
routeGet("/api/user-options/list", (ctx) => ctx.runQuery(api.userOptions.list, {}));
routePost("/api/user-options/add", (ctx, body) => ctx.runMutation(api.userOptions.add, body));
routePost("/api/user-options/update-color", (ctx, body) => ctx.runMutation(api.userOptions.updateColor, body));
routePost("/api/user-options/remove", (ctx, body) => ctx.runMutation(api.userOptions.remove, body));
routePost("/api/user-options/set-default", (ctx, body) => ctx.runMutation(api.userOptions.setDefault, body));
routePost("/api/user-options/set-tracking", (ctx, body) => ctx.runMutation(api.userOptions.setTracking, body));
routePost("/api/user-options/rename", (ctx, body) => ctx.runMutation(api.userOptions.rename, body));
routePost("/api/user-options/move-to-subtype", (ctx, body) => ctx.runMutation(api.userOptions.moveToSubtype, body));
routePost("/api/user-options/promote-subtype", (ctx, body) => ctx.runMutation(api.userOptions.promoteSubtype, body));
routePost("/api/user-options/move-subtype", (ctx, body) => ctx.runMutation(api.userOptions.moveSubtype, body));

// Payback links
routePost("/api/payback-links/list-for-expense", (ctx, body) => ctx.runQuery(api.paybackLinks.listForExpense, body));
routePost("/api/payback-links/list-for-incoming", (ctx, body) => ctx.runQuery(api.paybackLinks.listForIncoming, body));
routeGet("/api/payback-links/list-incoming-candidates", (ctx) => ctx.runQuery(api.paybackLinks.listIncomingCandidates, {}));
routeGet("/api/payback-links/list-expense-candidates", (ctx) => ctx.runQuery(api.paybackLinks.listExpenseCandidates, {}));
routePost("/api/payback-links/create", (ctx, body) => ctx.runMutation(api.paybackLinks.create, body));
routePost("/api/payback-links/update", (ctx, body) => ctx.runMutation(api.paybackLinks.update, body));
routePost("/api/payback-links/remove", (ctx, body) => ctx.runMutation(api.paybackLinks.remove, body));

function routeGet(path: string, run: (ctx: Parameters<typeof httpAction>[0] extends never ? never : any) => Promise<unknown>) {
  http.route({
    path,
    method: "GET",
    handler: httpAction(async (ctx) => {
      try {
        return jsonOk(await run(ctx));
      } catch (error) {
        return mapError(error);
      }
    }),
  });
}

function routePost(path: string, run: (ctx: any, body: any) => Promise<unknown>) {
  http.route({
    path,
    method: "POST",
    handler: httpAction(async (ctx, request) => {
      try {
        const body = await parseBody(request);
        return jsonOk(await run(ctx, body));
      } catch (error) {
        return mapError(error);
      }
    }),
  });
}

async function parseBody(request: Request) {
  const text = await request.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function mapError(error: unknown): Response {
  const message = error instanceof Error ? error.message : "Unexpected error";
  if (message.includes("Unauthenticated")) {
    return jsonError(401, "unauthorized", "Unauthenticated");
  }
  if (message.includes("Not found") || message.includes("not found")) {
    return jsonError(404, "not_found", message);
  }
  if (message.includes("Missing") || message.includes("required") || message.includes("must")) {
    return jsonError(422, "validation", message);
  }
  return jsonError(500, "server", message);
}

function jsonOk(data: unknown): Response {
  return new Response(JSON.stringify({ ok: true, data }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

function jsonError(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ ok: false, error: { code, message } }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

export default http;
