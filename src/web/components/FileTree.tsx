import type { FileNode } from "../../shared/types";

type Props = {
  nodes: FileNode[];
  currentPath: string | null;
  onSelect: (path: string) => void;
};

export function FileTree({ nodes, currentPath, onSelect }: Props) {
  return (
    <nav className="file-tree" aria-label="Markdown files">
      {nodes.map((node) => (
        <TreeNode key={node.path} node={node} currentPath={currentPath} onSelect={onSelect} />
      ))}
    </nav>
  );
}

function TreeNode({ node, currentPath, onSelect }: { node: FileNode; currentPath: string | null; onSelect: (path: string) => void }) {
  if (node.type === "directory") {
    return (
      <div className="tree-directory">
        <div className="tree-directory-name">{node.name}</div>
        <div className="tree-children">
          {(node.children ?? []).map((child) => (
            <TreeNode key={child.path} node={child} currentPath={currentPath} onSelect={onSelect} />
          ))}
        </div>
      </div>
    );
  }
  return (
    <button className={node.path === currentPath ? "tree-file active" : "tree-file"} onClick={() => onSelect(node.path)}>
      {node.name}
    </button>
  );
}
