import Lean.Meta.ExprLens
import ProofWidgets.Component.Panel
import ProofWidgets.Presentation.Expr -- Needed for RPC calls in SelectionPanel

namespace ProofWidgets
open Lean Server

structure GoalsLocationsToExprsParams where
  locations : Array (WithRpcRef Elab.ContextInfo × SubExpr.GoalsLocation)

#mkrpcenc GoalsLocationsToExprsParams

structure GoalsLocationsToExprsResponse where
  exprs : Array (WithRpcRef ExprWithCtx)

#mkrpcenc GoalsLocationsToExprsResponse

/-- Compute expressions corresponding to the given `GoalsLocation`s. -/
@[server_rpc_method]
def goalsLocationsToExprs (args : GoalsLocationsToExprsParams) :
    RequestM (RequestTask GoalsLocationsToExprsResponse) :=
  RequestM.asTask do
    let mut exprs := #[]
    for ⟨⟨ci⟩, loc⟩ in args.locations do
      exprs := exprs.push ⟨← ci.runMetaM {} <| go loc.mvarId loc.loc⟩
    return { exprs }
where
  go (mvarId : MVarId) : SubExpr.GoalLocation → MetaM ExprWithCtx
  | .hyp fv =>
    mvarId.withContext <|
      ExprWithCtx.save (mkFVar fv)
  | .hypType fv pos => mvarId.withContext do
    let tp ← Meta.inferType (mkFVar fv)
    Meta.viewSubexpr (visit := fun _ => ExprWithCtx.save) pos tp
  | .hypValue fv pos => mvarId.withContext do
    let some val ← fv.getValue?
      | throwError "fvar {mkFVar fv} is not a let-binding"
    Meta.viewSubexpr (visit := fun _ => ExprWithCtx.save) pos val
  | .target pos => mvarId.withContext do
    let tp ← Meta.inferType (mkMVar mvarId)
    Meta.viewSubexpr (visit := fun _ => ExprWithCtx.save) pos tp

/-- Display a list of all expressions selected in the goal state, with a choice of which `Expr`
presenter should be used to display each of those expressions. -/
@[widget_module]
def SelectionPanel : Component PanelWidgetProps where
  javascript := include_str ".." / ".." / "build" / "js" / "presentSelection.js"

end ProofWidgets